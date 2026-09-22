import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/pose/angle_calculator.dart';
import '../../../core/pose/body_region.dart';
import '../../../core/pose/body_view.dart';
import '../../../models/session_metadata.dart';
import '../../../theme/app_colors.dart';
import '../../exercises/exercise_catalog.dart';

/// Gráfica del ángulo de una articulación a lo largo de una sesión —
/// relee `datos.csv` (ya exportado al terminar de grabar/importar), no
/// necesita ningún dato nuevo. El paciente puede elegir qué articulación
/// ver con el selector de arriba.
class MovementChart extends StatefulWidget {
  const MovementChart({super.key, required this.dir, required this.metadata});

  final Directory dir;
  final SessionMetadata metadata;

  @override
  State<MovementChart> createState() => _MovementChartState();
}

class _MovementChartState extends State<MovementChart> {
  late final Future<Map<String, List<(double timeMs, double? angle)>>> _future;
  String? _selectedLabel;

  @override
  void initState() {
    super.initState();
    _future = _loadCsv();
  }

  Future<Map<String, List<(double, double?)>>> _loadCsv() async {
    final file = File('${widget.dir.path}/datos.csv');
    if (!await file.exists()) return {};

    final lines = await file.readAsLines();
    if (lines.length < 2) return {};

    final headers = lines.first.split(',');
    final timeIndex = headers.indexOf('tiempo_ms');
    if (timeIndex == -1) return {};

    final trackedJoints = trackedJointsForExerciseId(widget.metadata.exerciseId);
    final activeDefs = jointDefinitions.where(
      (d) =>
          isJointActiveForView(d.kind, widget.metadata.view) &&
          isJointActiveForRegion(d.kind, widget.metadata.region) &&
          (trackedJoints == null || trackedJoints.contains(d.kind)),
    );

    final result = <String, List<(double, double?)>>{};
    for (final def in activeDefs) {
      final columnIndex = headers.indexOf(def.csvColumn);
      if (columnIndex == -1) continue;

      final points = <(double, double?)>[];
      for (final line in lines.skip(1)) {
        if (line.trim().isEmpty) continue;
        final cells = line.split(',');
        final timeMs = double.tryParse(cells[timeIndex]) ?? 0;
        final raw = columnIndex < cells.length ? cells[columnIndex] : '';
        points.add((timeMs, raw.isEmpty ? null : double.tryParse(raw)));
      }
      result[def.label] = points;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<(double, double?)>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data ?? {};
        if (data.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No hay datos suficientes para graficar esta sesión.',
              style: TextStyle(color: AppColors.lowConfidence),
            ),
          );
        }

        _selectedLabel ??= data.keys.first;
        final points = data[_selectedLabel] ?? const [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: _selectedLabel,
              isExpanded: true,
              items: [
                for (final label in data.keys)
                  DropdownMenuItem(value: label, child: Text(label)),
              ],
              onChanged: (label) => setState(() => _selectedLabel = label),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              width: double.infinity,
              child: CustomPaint(painter: _MovementLinePainter(points: points)),
            ),
          ],
        );
      },
    );
  }
}

class _MovementLinePainter extends CustomPainter {
  const _MovementLinePainter({required this.points});

  final List<(double timeMs, double? angle)> points;

  static const _paddingLeft = 36.0;
  static const _paddingBottom = 22.0;
  static const _paddingTop = 12.0;
  static const _paddingRight = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final validAngles = points.map((p) => p.$2).whereType<double>().toList();
    if (points.isEmpty || validAngles.isEmpty) {
      _drawLabel(canvas, 'Sin datos válidos para esta articulación', const Offset(4, 4));
      return;
    }

    final minY = validAngles.reduce(math.min);
    final maxY = validAngles.reduce(math.max);
    final rangeY = (maxY - minY).abs() < 1e-6 ? 1.0 : maxY - minY;
    final minX = points.first.$1;
    final maxX = points.last.$1;
    final rangeX = (maxX - minX).abs() < 1e-6 ? 1.0 : maxX - minX;

    final chartWidth = size.width - _paddingLeft - _paddingRight;
    final chartHeight = size.height - _paddingTop - _paddingBottom;

    Offset toChart(double x, double y) => Offset(
      _paddingLeft + (x - minX) / rangeX * chartWidth,
      _paddingTop + (1 - (y - minY) / rangeY) * chartHeight,
    );

    final axisPaint = Paint()
      ..color = AppColors.lowConfidence
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(_paddingLeft, _paddingTop),
      Offset(_paddingLeft, _paddingTop + chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(_paddingLeft, _paddingTop + chartHeight),
      Offset(_paddingLeft + chartWidth, _paddingTop + chartHeight),
      axisPaint,
    );

    _drawLabel(canvas, '${maxY.round()}°', Offset(2, _paddingTop - 6));
    _drawLabel(canvas, '${minY.round()}°', Offset(2, _paddingTop + chartHeight - 6));
    _drawLabel(canvas, '0s', Offset(_paddingLeft, _paddingTop + chartHeight + 4));
    _drawLabel(
      canvas,
      '${(rangeX / 1000).toStringAsFixed(1)}s',
      Offset(_paddingLeft + chartWidth - 26, _paddingTop + chartHeight + 4),
    );

    // Un segmento de línea por cada tramo continuo de valores no nulos —
    // así los huecos (articulación no visible en ciertos cuadros) quedan
    // como cortes en la línea, no como un salto recto que inventaría datos.
    final linePaint = Paint()
      ..color = AppColors.orangeAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    Path? current;
    for (final (t, angle) in points) {
      if (angle == null) {
        if (current != null) canvas.drawPath(current, linePaint);
        current = null;
        continue;
      }
      final p = toChart(t, angle);
      if (current == null) {
        current = Path()..moveTo(p.dx, p.dy);
      } else {
        current.lineTo(p.dx, p.dy);
      }
    }
    if (current != null) canvas.drawPath(current, linePaint);
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.darkGrey, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _MovementLinePainter oldDelegate) =>
      oldDelegate.points != points;
}
