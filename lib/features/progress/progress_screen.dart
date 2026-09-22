import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/pose/angle_calculator.dart';
import '../../models/exercise.dart';
import '../../services/patient/patient_profile_service.dart';
import '../../services/storage/session_loader.dart';
import '../../services/storage/session_storage_service.dart';
import '../../theme/app_colors.dart';
import '../exercises/exercise_catalog.dart';
import '../sessions/session_detail_screen.dart';
import 'day_summary_screen.dart';
import 'progress_calendar.dart';

/// Qué tipo de gráfica mostrar en ProgressScreen — el paciente puede
/// cambiar entre ellas, cada una resalta algo distinto del mismo dato: la
/// línea muestra la tendencia sesión a sesión, el termómetro y el arco
/// resaltan qué tan cerca está la sesión más reciente del objetivo
/// clínico (el arco replica el estilo de medidor/protractor de
/// `patologias_objetivo.docx`).
enum _ChartType { line, thermometer, arc }

/// Evolución del rango de movimiento de [patientProfile] a lo largo de las
/// sesiones — agrupada **por ejercicio**, no solo por patología: hombro
/// tiene 2 movimientos (flexión y abducción) que son clínicamente
/// distintos aunque midan la misma articulación, así que cada uno tiene su
/// propia gráfica en vez de mezclarse en una sola línea de tiempo.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.patientProfile});

  final PatientProfile patientProfile;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressPoint {
  const _ProgressPoint({required this.date, required this.rom, required this.session});

  final DateTime date;
  final double rom;
  final SavedSession session;
}

/// Todas las sesiones de un mismo ejercicio, ya ordenadas por fecha.
class _ExerciseProgress {
  const _ExerciseProgress({required this.exercise, required this.points});

  final Exercise exercise;
  final List<_ProgressPoint> points;
}

/// Todo lo que necesita pintar la pantalla: el progreso por ejercicio para
/// las gráficas, y el mapa día→sesiones para el calendario (que junta
/// TODOS los ejercicios de la patología, a diferencia de las gráficas que
/// van separadas por ejercicio).
class _ProgressData {
  const _ProgressData({
    required this.exercises,
    required this.sessionsByDay,
    required this.firstTrackedDay,
  });

  final List<_ExerciseProgress> exercises;
  final Map<DateTime, List<SavedSession>> sessionsByDay;
  final DateTime? firstTrackedDay;
}

DateTime _normalizeDay(DateTime d) => DateTime(d.year, d.month, d.day);

class _ProgressScreenState extends State<ProgressScreen> {
  final _storage = SessionStorageService();
  late Future<_ProgressData> _future;
  _ChartType _chartType = _ChartType.line;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProgressData> _load() async {
    final pathology = widget.patientProfile.pathology;
    final side = widget.patientProfile.affectedSide;
    final all = await loadAllSessions(_storage);

    final byExercise = <String, List<_ProgressPoint>>{};
    final sessionsByDay = <DateTime, List<SavedSession>>{};
    DateTime? firstTrackedDay;

    for (final session in all) {
      final metadata = session.metadata;
      if (metadata.patientName != widget.patientProfile.name) continue;
      final exerciseId = metadata.exerciseId;
      if (exerciseId == null || !pathology.exerciseIds.contains(exerciseId)) continue;

      final day = _normalizeDay(metadata.startedAt);
      (sessionsByDay[day] ??= []).add(session);
      if (firstTrackedDay == null || day.isBefore(firstTrackedDay)) {
        firstTrackedDay = day;
      }

      final exercise = exerciseForId(exerciseId);
      if (exercise == null) continue;
      final joint = exercise.trackedJointFor(side);
      if (joint == null) continue;
      final def = jointDefinitions.firstWhere((d) => d.kind == joint);
      final stats = metadata.jointStats[def.csvColumn];
      if (stats == null) continue;

      (byExercise[exerciseId] ??= []).add(
        _ProgressPoint(date: metadata.startedAt, rom: stats.max, session: session),
      );
    }

    final result = <_ExerciseProgress>[];
    for (final exerciseId in pathology.exerciseIds) {
      final points = byExercise[exerciseId];
      if (points == null || points.isEmpty) continue;
      points.sort((a, b) => a.date.compareTo(b.date));
      final exercise = exerciseForId(exerciseId)!;
      result.add(_ExerciseProgress(exercise: exercise, points: points));
    }
    for (final list in sessionsByDay.values) {
      list.sort((a, b) => a.metadata.startedAt.compareTo(b.metadata.startedAt));
    }
    return _ProgressData(
      exercises: result,
      sessionsByDay: sessionsByDay,
      firstTrackedDay: firstTrackedDay,
    );
  }

  Future<void> _refresh() async {
    final data = await _load();
    if (!mounted) return;
    setState(() => _future = Future.value(data));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi progreso')),
      body: FutureBuilder<_ProgressData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          final groups = data?.exercises ?? const [];
          if (data == null || (groups.isEmpty && data.sessionsByDay.isEmpty)) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Todavía no hay sesiones de tus ejercicios para '
                          'mostrar progreso.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lowConfidence.withValues(alpha: 0.2)),
                  ),
                  child: ProgressCalendar(
                    sessionsByDay: data.sessionsByDay,
                    firstTrackedDay: data.firstTrackedDay,
                    onDaySelected: (day, sessions) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DaySummaryScreen(day: day, sessions: sessions),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Todavía no hay suficientes sesiones para mostrar una gráfica.',
                      style: TextStyle(color: AppColors.lowConfidence),
                    ),
                  ),
                if (groups.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: SegmentedButton<_ChartType>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
                    ),
                    segments: const [
                      ButtonSegment(value: _ChartType.line, icon: Icon(Icons.show_chart, size: 18)),
                      ButtonSegment(
                        value: _ChartType.thermometer,
                        icon: Icon(Icons.thermostat_outlined, size: 18),
                      ),
                      ButtonSegment(value: _ChartType.arc, icon: Icon(Icons.speed_outlined, size: 18)),
                    ],
                    selected: {_chartType},
                    onSelectionChanged: (s) => setState(() => _chartType = s.first),
                  ),
                ),
                const SizedBox(height: 8),
                for (final group in groups) ...[
                  _ExerciseProgressSection(
                    group: group,
                    targetRom: widget.patientProfile.pathology.targetRomFor(group.exercise.id),
                    chartType: _chartType,
                    onOpenSession: (point) async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SessionDetailScreen(
                            dir: point.session.dir,
                            metadata: point.session.metadata,
                          ),
                        ),
                      );
                      _refresh();
                    },
                  ),
                  const SizedBox(height: 28),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExerciseProgressSection extends StatelessWidget {
  const _ExerciseProgressSection({
    required this.group,
    required this.targetRom,
    required this.chartType,
    required this.onOpenSession,
  });

  final _ExerciseProgress group;
  final double targetRom;
  final _ChartType chartType;
  final ValueChanged<_ProgressPoint> onOpenSession;

  @override
  Widget build(BuildContext context) {
    final points = group.points;
    final baseline = points.first.rom;
    final current = points.last.rom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progreso — ${group.exercise.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Rango de movimiento logrado por sesión (más alto = más progreso).',
          style: TextStyle(color: AppColors.darkGrey.withValues(alpha: 0.6), fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (chartType == _ChartType.line) ...[
          SizedBox(
            height: 240,
            child: CustomPaint(
              painter: _ProgressChartPainter(points: points, target: targetRom, baseline: baseline),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              const _Legend(color: AppColors.tealPrimary, label: 'Progreso real'),
              _Legend(color: AppColors.success, label: 'Objetivo clínico (${targetRom.round()}°)'),
              _Legend(color: AppColors.lowConfidence, label: 'Primera sesión (${baseline.round()}°)'),
            ],
          ),
        ] else if (chartType == _ChartType.thermometer)
          Center(
            child: SizedBox(
              height: 320,
              child: CustomPaint(
                painter: _ThermometerPainter(current: current, baseline: baseline, target: targetRom),
                child: const SizedBox(width: 260, height: 320),
              ),
            ),
          )
        else
          Center(
            child: SizedBox(
              height: 220,
              child: CustomPaint(
                painter: _ArcGaugePainter(current: current, baseline: baseline, target: targetRom),
                child: const SizedBox(width: 280, height: 220),
              ),
            ),
          ),
        const SizedBox(height: 12),
        for (final point in points.reversed)
          _SessionProgressTile(point: point, onTap: () => onOpenSession(point)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _SessionProgressTile extends StatelessWidget {
  const _SessionProgressTile({required this.point, required this.onTap});

  final _ProgressPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = point.date;
    final dateLabel = '${two(d.day)}/${two(d.month)}/${d.year}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: AppColors.tealPrimary,
        child: Icon(Icons.videocam_outlined, color: Colors.white),
      ),
      title: Text(dateLabel),
      subtitle: const Text('Toca para ver el detalle, la gráfica y el video'),
      trailing: Text(
        '${point.rom.round()}°',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.tealPrimary),
      ),
      onTap: onTap,
    );
  }
}

class _ProgressChartPainter extends CustomPainter {
  const _ProgressChartPainter({required this.points, required this.target, required this.baseline});

  final List<_ProgressPoint> points;
  final double target;
  final double baseline;

  static const _paddingLeft = 40.0;
  static const _paddingBottom = 22.0;
  static const _paddingTop = 14.0;
  static const _paddingRight = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [...points.map((p) => p.rom), target, baseline];
    final minY = math.min(0.0, values.reduce(math.min));
    final maxY = values.reduce(math.max) * 1.05;
    final rangeY = (maxY - minY).abs() < 1e-6 ? 1.0 : maxY - minY;

    final minX = points.first.date.millisecondsSinceEpoch.toDouble();
    final lastX = points.last.date.millisecondsSinceEpoch.toDouble();
    final rawRangeX = lastX - minX;
    // Deja espacio vacío a la derecha del último punto, a modo de "próximas
    // sesiones" — si no, la línea queda pegada al borde derecho y no se lee
    // como una gráfica que sigue en progreso, sino como un dato cerrado.
    final weekMs = const Duration(days: 7).inMilliseconds.toDouble();
    final extension = rawRangeX < weekMs ? weekMs : rawRangeX * 0.35;
    final maxX = lastX + extension;
    final rangeX = maxX - minX;

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

    void drawDashedHLine(double y, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2;
      const dash = 6.0;
      const gap = 4.0;
      var x = _paddingLeft;
      final yPos = toChart(minX, y).dy;
      while (x < _paddingLeft + chartWidth) {
        canvas.drawLine(Offset(x, yPos), Offset(math.min(x + dash, _paddingLeft + chartWidth), yPos), paint);
        x += dash + gap;
      }
    }

    drawDashedHLine(target, AppColors.success);
    drawDashedHLine(baseline, AppColors.lowConfidence);

    _drawLabel(canvas, '${maxY.round()}°', const Offset(2, _paddingTop - 4), AppColors.darkGrey, 11);
    _drawLabel(
      canvas,
      '${minY.round()}°',
      Offset(2, _paddingTop + chartHeight - 8),
      AppColors.darkGrey,
      11,
    );

    final linePaint = Paint()
      ..color = AppColors.tealPrimary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = AppColors.tealPrimary;
    final dotRingPaint = Paint()
      ..color = AppColors.tealPrimary.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = toChart(points[i].date.millisecondsSinceEpoch.toDouble(), points[i].rom);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, linePaint);
    for (var i = 0; i < points.length; i++) {
      final p = toChart(points[i].date.millisecondsSinceEpoch.toDouble(), points[i].rom);
      canvas.drawCircle(p, 5, dotPaint);
      canvas.drawCircle(p, 8, dotRingPaint);
    }

    // Etiqueta directa solo en el último punto (el más reciente) — no en
    // todos, para no saturar la gráfica.
    final last = toChart(points.last.date.millisecondsSinceEpoch.toDouble(), points.last.rom);
    _drawLabel(
      canvas,
      '${points.last.rom.round()}°',
      last + const Offset(8, -18),
      AppColors.tealPrimary,
      13,
      bold: true,
    );

    // Marca dónde termina lo ya medido y empieza el espacio para las
    // próximas sesiones — línea punteada vertical, tenue, más un texto
    // chico ahí mismo.
    final futurePaint = Paint()
      ..color = AppColors.lowConfidence.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;
    var y = _paddingTop;
    const dashV = 4.0;
    const gapV = 3.0;
    while (y < _paddingTop + chartHeight) {
      canvas.drawLine(
        Offset(last.dx, y),
        Offset(last.dx, math.min(y + dashV, _paddingTop + chartHeight)),
        futurePaint,
      );
      y += dashV + gapV;
    }
    _drawLabel(
      canvas,
      'Próximas\nsesiones',
      Offset(last.dx + 10, _paddingTop + chartHeight - 34),
      AppColors.darkGrey.withValues(alpha: 0.45),
      10,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ProgressChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.target != target ||
      oldDelegate.baseline != baseline;
}

/// Gráfica tipo termómetro: un tubo vertical que se llena hasta el rango
/// logrado en la sesión más reciente, con marcas para el objetivo clínico
/// (arriba) y la primera sesión (abajo) — resalta de un vistazo qué tan
/// cerca está el paciente de su meta, en vez de la tendencia en el tiempo
/// (eso lo muestra la gráfica de línea).
class _ThermometerPainter extends CustomPainter {
  const _ThermometerPainter({required this.current, required this.baseline, required this.target});

  final double current;
  final double baseline;
  final double target;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = math.min(baseline, math.min(current, target));
    final hi = math.max(target, math.max(current, baseline));
    final range = (hi - lo).abs() < 1e-6 ? 1.0 : hi - lo;
    double frac(double v) => ((v - lo) / range).clamp(0.0, 1.0);

    const tubeWidth = 46.0;
    final bulbRadius = tubeWidth * 0.85;
    final cx = size.width / 2;
    final bulbCenterY = size.height - bulbRadius - 8;
    final tubeTop = 40.0;
    final tubeBottom = bulbCenterY - bulbRadius * 0.35;
    final tubeHeight = tubeBottom - tubeTop;

    final trackPaint = Paint()..color = AppColors.lowConfidence.withValues(alpha: 0.18);
    final fillPaint = Paint()..color = AppColors.tealPrimary;

    final tubeRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - tubeWidth / 2, tubeTop, cx + tubeWidth / 2, tubeBottom),
      Radius.circular(tubeWidth / 2),
    );

    // Track + bulbo vacíos primero (color base), luego el relleno recorta
    // por encima con un clip — evita que el relleno se salga del tubo.
    canvas.drawRRect(tubeRect, trackPaint);
    canvas.drawCircle(Offset(cx, bulbCenterY), bulbRadius, trackPaint);

    canvas.save();
    final fillPath = Path()
      ..addRRect(tubeRect)
      ..addOval(Rect.fromCircle(center: Offset(cx, bulbCenterY), radius: bulbRadius));
    canvas.clipPath(fillPath);
    final fillTopY = tubeBottom - frac(current) * tubeHeight;
    canvas.drawRect(Rect.fromLTRB(cx - tubeWidth, fillTopY, cx + tubeWidth, size.height), fillPaint);
    canvas.restore();

    // Marcas de referencia (objetivo/primera sesión) — línea punteada
    // horizontal cruzando el tubo, con su valor al lado.
    void drawMarker(double value, Color color, String label, {required bool labelAbove}) {
      final y = tubeBottom - frac(value) * tubeHeight;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2;
      const dash = 4.0;
      const gap = 3.0;
      var x = cx - tubeWidth / 2 - 4;
      final xEnd = cx + tubeWidth / 2 + 4;
      while (x < xEnd) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, xEnd), y), paint);
        x += dash + gap;
      }
      _drawLabel(
        canvas,
        label,
        Offset(xEnd + 6, y - (labelAbove ? 14 : 0)),
        color,
        11,
        bold: false,
      );
    }

    drawMarker(target, AppColors.success, 'Objetivo\n${target.round()}°', labelAbove: true);
    drawMarker(baseline, AppColors.lowConfidence, 'Primera sesión\n${baseline.round()}°', labelAbove: false);

    // Valor actual, grande, arriba del tubo.
    _drawLabel(
      canvas,
      '${current.round()}°',
      Offset(cx - 20, tubeTop - 30),
      AppColors.tealPrimary,
      22,
      bold: true,
    );
    _drawLabel(canvas, 'Última sesión', Offset(cx - 34, tubeTop - 46), AppColors.darkGrey, 11);
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ThermometerPainter oldDelegate) =>
      oldDelegate.current != current ||
      oldDelegate.baseline != baseline ||
      oldDelegate.target != target;
}

/// Gráfica tipo medidor/protractor (semicírculo), al estilo de los
/// diagramas de rango de `patologias_objetivo.docx`: un arco de fondo
/// (rango completo) y un arco relleno hasta el valor logrado en la sesión
/// más reciente, con marcas para el objetivo clínico y la primera sesión.
class _ArcGaugePainter extends CustomPainter {
  const _ArcGaugePainter({required this.current, required this.baseline, required this.target});

  final double current;
  final double baseline;
  final double target;

  static const _startAngle = math.pi; // 9 en punto
  static const _sweepFull = math.pi; // medio círculo, hasta las 3 en punto

  @override
  void paint(Canvas canvas, Size size) {
    final lo = math.min(0.0, math.min(baseline, math.min(current, target)));
    final hi = math.max(target, math.max(current, baseline));
    final range = (hi - lo).abs() < 1e-6 ? 1.0 : hi - lo;
    double frac(double v) => ((v - lo) / range).clamp(0.0, 1.0);

    final cx = size.width / 2;
    final cy = size.height - 24;
    final radius = math.min(size.width / 2, size.height) - 28;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    const strokeWidth = 20.0;
    final trackPaint = Paint()
      ..color = AppColors.lowConfidence.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepFull, false, trackPaint);

    final fillPaint = Paint()
      ..color = AppColors.tealPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepFull * frac(current), false, fillPaint);

    void drawTick(double value, Color color, {required bool above}) {
      final angle = _startAngle + _sweepFull * frac(value);
      final inner = Offset(
        cx + (radius - strokeWidth / 2 - 4) * math.cos(angle),
        cy + (radius - strokeWidth / 2 - 4) * math.sin(angle),
      );
      final outer = Offset(
        cx + (radius + strokeWidth / 2 + 4) * math.cos(angle),
        cy + (radius + strokeWidth / 2 + 4) * math.sin(angle),
      );
      canvas.drawLine(inner, outer, Paint()..color = color..strokeWidth = 3);
      final labelPos = Offset(
        cx + (radius + strokeWidth / 2 + 10) * math.cos(angle) - (above ? 10 : 10),
        cy + (radius + strokeWidth / 2 + 10) * math.sin(angle) - (above ? 22 : 4),
      );
      _drawLabel(canvas, '${value.round()}°', labelPos, color, 11, bold: false);
    }

    drawTick(target, AppColors.success, above: true);
    drawTick(baseline, AppColors.lowConfidence, above: false);

    // Valor actual, grande, en el centro del arco.
    final currentText = '${current.round()}°';
    final tp = TextPainter(
      text: TextSpan(
        text: currentText,
        style: const TextStyle(color: AppColors.tealPrimary, fontSize: 26, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - radius * 0.55));
    _drawLabel(
      canvas,
      'Última sesión',
      Offset(cx - 34, cy - radius * 0.55 - 16),
      AppColors.darkGrey,
      11,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter oldDelegate) =>
      oldDelegate.current != current ||
      oldDelegate.baseline != baseline ||
      oldDelegate.target != target;
}
