import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/pose/angle_calculator.dart';
import '../../core/utilidades/session_naming.dart';
import '../../modelos/exercise.dart';
import '../../services/paciente/patient_profile_service.dart';
import '../../services/almacenamiento/session_loader.dart';
import '../../services/almacenamiento/session_storage_service.dart';
import '../../tema/app_colors.dart';
import '../ejercicios/exercise_catalog.dart';
import '../sesiones/session_detail_screen.dart';
import 'day_summary_screen.dart';
import 'progress_calendar.dart';

/// Qué tipo de gráfica mostrar en ProgressScreen — el paciente puede
/// cambiar entre ellas, cada una resalta qué tan cerca está la sesión más
/// reciente del objetivo clínico (el arco replica el estilo de medidor/
/// protractor de `patologias_objetivo.docx`). Hubo una tercera opción de
/// línea de tendencia, pero se quitó por verse mal.
enum _ChartType { thermometer, arc }

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

/// Color según qué tan cerca está [current] de [target] — mismo criterio
/// (rojo/naranja/amarillo/verde) que [_fixedZones], usado para el número
/// grande de "última sesión" en el termómetro y el arco (un texto sí puede
/// cambiar de color con los datos; los FONDOS de zona no, ver esa función).
/// Verde desde que se alcanza o supera el objetivo, no solo al llegar
/// exacto.
Color _proximityColor(double current, double target) {
  if (target <= 0) return AppColors.tealPrimary;
  final fraction = current / target;
  if (fraction >= 1.0) return AppColors.success;
  if (fraction >= 0.75) return AppColors.warning;
  if (fraction >= 0.5) return AppColors.orangeAccent;
  return AppColors.danger;
}

/// Las 4 zonas de color — SIEMPRE las mismas 4 fracciones de [target] (0-
/// 50% rojo, 50-75% naranja, 75-100% amarillo, 100%+ verde), a diferencia
/// de antes, donde el color dependía de dónde caían los datos de cada
/// sesión en particular. Se pintan como fondo fijo en la línea, el
/// termómetro y el arco — así "zona verde" siempre significa lo mismo sin
/// importar el paciente ni la sesión; lo único que se mueve sobre ese
/// fondo fijo es el indicador/línea/aguja de la sesión más reciente.
List<(double lo, double hi, Color color)> _fixedZones(double target) => [
  (0.0, 0.5 * target, AppColors.danger),
  (0.5 * target, 0.75 * target, AppColors.orangeAccent),
  (0.75 * target, target, AppColors.warning),
  (target, double.infinity, AppColors.success),
];

class _ProgressScreenState extends State<ProgressScreen> {
  final _storage = SessionStorageService();
  late Future<_ProgressData> _future;
  _ChartType _chartType = _ChartType.thermometer;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProgressData> _load() async {
    final pathology = widget.patientProfile.pathology;
    final side = widget.patientProfile.affectedSide;
    final all = await loadAllSessions(_storage);

    // Por ejercicio Y por día — si el paciente mide el mismo ejercicio más
    // de una vez el mismo día, todas esas sesiones se siguen guardando
    // (ver `sessionsByDay`/calendario/DaySummaryScreen, que las muestra
    // todas), pero la gráfica de progreso solo toma la ÚLTIMA de ese día
    // como el punto representativo — si no, 3 mediciones seguidas el mismo
    // día aparecían como 3 puntos casi pegados, ensuciando la tendencia
    // sesión a sesión en vez de mostrarla.
    final byExerciseDay = <String, Map<DateTime, _ProgressPoint>>{};
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

      final dayMap = byExerciseDay[exerciseId] ??= {};
      final existing = dayMap[day];
      if (existing == null || metadata.startedAt.isAfter(existing.date)) {
        dayMap[day] = _ProgressPoint(date: metadata.startedAt, rom: stats.max, session: session);
      }
    }

    final result = <_ExerciseProgress>[];
    for (final exerciseId in pathology.exerciseIds) {
      final dayMap = byExerciseDay[exerciseId];
      if (dayMap == null || dayMap.isEmpty) continue;
      final points = dayMap.values.toList()..sort((a, b) => a.date.compareTo(b.date));
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
          'Progreso: ${group.exercise.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Rango de movimiento logrado por sesión (más alto = más progreso).',
          style: TextStyle(color: AppColors.darkGrey.withValues(alpha: 0.6), fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (chartType == _ChartType.thermometer)
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
        const SizedBox(height: 8),
        // Leyenda de las 4 zonas fijas — igual en las 2 gráficas (ver
        // _fixedZones), para no repetir la explicación por cada tipo.
        const Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _Legend(color: AppColors.danger, label: 'Lejos de la meta'),
            _Legend(color: AppColors.orangeAccent, label: 'Avanzando'),
            _Legend(color: AppColors.warning, label: 'Casi'),
            _Legend(color: AppColors.success, label: 'Meta alcanzada'),
          ],
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
    final dateLabel = formatDateWords(point.date);
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

/// Gráfica tipo termómetro: un tubo vertical que se llena hasta el rango
/// logrado en la sesión más reciente, con marcas para el objetivo clínico
/// (arriba) y la primera sesión (abajo) — resalta de un vistazo qué tan
/// cerca está el paciente de su meta.
class _ThermometerPainter extends CustomPainter {
  const _ThermometerPainter({required this.current, required this.baseline, required this.target});

  final double current;
  final double baseline;
  final double target;

  @override
  void paint(Canvas canvas, Size size) {
    // Eje FIJO (0 a 120% de la meta, o más si algún dato se sale de ahí) —
    // ya no depende de baseline/current como antes, para que las 4 zonas
    // de color siempre representen la misma fracción de la meta.
    final hi = math.max(target * 1.2, math.max(current, baseline) * 1.05);
    double frac(double v) => (v / hi).clamp(0.0, 1.0);

    const tubeWidth = 46.0;
    final bulbRadius = tubeWidth * 0.85;
    final cx = size.width / 2;
    final bulbCenterY = size.height - bulbRadius - 8;
    final tubeTop = 40.0;
    final tubeBottom = bulbCenterY - bulbRadius * 0.35;
    final tubeHeight = tubeBottom - tubeTop;

    final tubeRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - tubeWidth / 2, tubeTop, cx + tubeWidth / 2, tubeBottom),
      Radius.circular(tubeWidth / 2),
    );

    // Bulbo: siempre zona roja (representa la base, 0) — no cambia.
    canvas.drawCircle(Offset(cx, bulbCenterY), bulbRadius, Paint()..color = AppColors.danger);

    // Tubo: las 4 zonas FIJAS de color (ver _fixedZones) — a diferencia de
    // antes, esto ya no es "relleno hasta el valor actual" en un solo
    // color: el fondo siempre se ve completo, y lo único que se mueve
    // sobre él es la línea indicadora de abajo.
    canvas.save();
    canvas.clipRRect(tubeRect);
    for (final zone in _fixedZones(target)) {
      final yBottom = tubeBottom - frac(zone.$1) * tubeHeight;
      final yTop = tubeBottom - frac(zone.$2.isFinite ? zone.$2 : hi) * tubeHeight;
      canvas.drawRect(
        Rect.fromLTRB(cx - tubeWidth, yTop, cx + tubeWidth, yBottom),
        Paint()..color = zone.$3,
      );
    }
    canvas.restore();

    // Marcas de referencia (objetivo/primera sesión) — línea punteada
    // horizontal cruzando el tubo, con su valor al lado. Colores neutros
    // (no rojo/naranja/amarillo/verde) para no confundirse con las zonas.
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

    drawMarker(target, Colors.black87, 'Objetivo\n${target.round()}°', labelAbove: true);
    drawMarker(baseline, AppColors.lowConfidence, 'Primera sesión\n${baseline.round()}°', labelAbove: false);

    // Indicador de la sesión más reciente — línea sólida blanca con borde
    // oscuro, para que se vea clara sobre cualquiera de las 4 zonas de
    // fondo. Es lo ÚNICO que se mueve de una sesión a otra.
    final markerY = tubeBottom - frac(current) * tubeHeight;
    final markerStart = Offset(cx - tubeWidth / 2 - 6, markerY);
    final markerEnd = Offset(cx + tubeWidth / 2 + 6, markerY);
    canvas.drawLine(
      markerStart,
      markerEnd,
      Paint()
        ..color = AppColors.tealDark
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      markerStart,
      markerEnd,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Valor actual, grande, arriba del tubo.
    _drawLabel(
      canvas,
      '${current.round()}°',
      Offset(cx - 20, tubeTop - 30),
      _proximityColor(current, target),
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
/// diagramas de rango de `patologias_objetivo.docx`: un arco de fondo con
/// las 4 zonas fijas de color (ver _fixedZones) y una aguja indicando el
/// valor logrado en la sesión más reciente, con marcas para el objetivo
/// clínico y la primera sesión.
class _ArcGaugePainter extends CustomPainter {
  const _ArcGaugePainter({required this.current, required this.baseline, required this.target});

  final double current;
  final double baseline;
  final double target;

  static const _startAngle = math.pi; // 9 en punto
  static const _sweepFull = math.pi; // medio círculo, hasta las 3 en punto

  @override
  void paint(Canvas canvas, Size size) {
    // Eje FIJO (0 a 120% de la meta, o más si algún dato se sale de ahí) —
    // ya no depende de baseline/current, para que las 4 zonas de color
    // siempre representen la misma fracción de la meta (ver _fixedZones).
    final hi = math.max(target * 1.2, math.max(current, baseline) * 1.05);
    double frac(double v) => (v / hi).clamp(0.0, 1.0);

    final cx = size.width / 2;
    final cy = size.height - 24;
    final radius = math.min(size.width / 2, size.height) - 28;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    const strokeWidth = 20.0;

    // Arco de fondo: las 4 zonas FIJAS de color — ya no un solo relleno de
    // 0 a "current" en un color, sino el fondo completo siempre visible,
    // con una aguja indicando la posición de la sesión más reciente (ver
    // abajo) — es lo único que se mueve de una sesión a otra.
    for (final zone in _fixedZones(target)) {
      final startFrac = frac(zone.$1);
      final endFrac = frac(zone.$2.isFinite ? zone.$2 : hi);
      if (endFrac <= startFrac) continue;
      canvas.drawArc(
        rect,
        _startAngle + _sweepFull * startFrac,
        _sweepFull * (endFrac - startFrac),
        false,
        Paint()
          ..color = zone.$3
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

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

    // Colores neutros (no rojo/naranja/amarillo/verde) para no confundirse
    // con las zonas de fondo.
    drawTick(target, Colors.black87, above: true);
    drawTick(baseline, AppColors.lowConfidence, above: false);

    // Aguja indicando la sesión más reciente.
    final needleAngle = _startAngle + _sweepFull * frac(current);
    final needleOuter = Offset(
      cx + radius * math.cos(needleAngle),
      cy + radius * math.sin(needleAngle),
    );
    final needleInner = Offset(
      cx + 12 * math.cos(needleAngle),
      cy + 12 * math.sin(needleAngle),
    );
    canvas.drawLine(
      needleInner,
      needleOuter,
      Paint()
        ..color = AppColors.tealDark
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx, cy), 7, Paint()..color = AppColors.tealDark);
    canvas.drawCircle(
      Offset(cx, cy),
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Valor actual, grande, en el centro del arco — mismo color que el relleno.
    final currentText = '${current.round()}°';
    final tp = TextPainter(
      text: TextSpan(
        text: currentText,
        style: TextStyle(
          color: _proximityColor(current, target),
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
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
