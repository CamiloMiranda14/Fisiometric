import 'dart:convert';

import '../core/pose/body_region.dart';
import '../core/pose/body_view.dart';
import 'recording_mode.dart';

/// Mínimo, máximo y promedio de una articulación a lo largo de una sesión.
class JointStats {
  const JointStats({required this.min, required this.max, required this.avg});

  final double min;
  final double max;
  final double avg;

  Map<String, dynamic> toJson() => {'min': min, 'max': max, 'avg': avg};

  factory JointStats.fromJson(Map<String, dynamic> json) => JointStats(
    min: (json['min'] as num).toDouble(),
    max: (json['max'] as num).toDouble(),
    avg: (json['avg'] as num).toDouble(),
  );
}

/// Resumen de una sesión guardada, escrito en `session.json` junto al video
/// y los archivos de datos — permite que la lista de sesiones (Fase 7)
/// cargue instantáneo sin releer y volver a calcular sobre el CSV completo
/// de cada una.
class SessionMetadata {
  const SessionMetadata({
    required this.id,
    required this.startedAt,
    required this.mode,
    required this.view,
    this.region = BodyRegion.fullBody,
    required this.durationMs,
    required this.sampleCount,
    required this.jointStats,
    required this.velocityStats,
    required this.videoFileName,
    this.patientName,
    this.exerciseId,
  });

  final String id;
  final DateTime startedAt;
  final RecordingMode mode;
  final BodyView view;

  /// Región del cuerpo medida — determina qué filas de articulación se
  /// muestran en SessionDetailScreen/SessionResultScreen (ver
  /// isJointActiveForRegion). `fullBody` para sesiones grabadas antes de
  /// agregar este campo, o sin un ejercicio específico (Prueba rápida).
  final BodyRegion region;

  final int durationMs;
  final int sampleCount;

  /// Nombre/identificador del paciente, si se ingresó antes de medir — solo
  /// para poder identificar de quién es cada sesión en la lista, sin
  /// perfiles ni login. `null`/vacío si no se ingresó ninguno.
  final String? patientName;

  /// `Exercise.id` del catálogo, si esta sesión vino de ExerciseDemoScreen
  /// (`null` para "Prueba rápida") — permite asociar la sesión a la
  /// patología correspondiente en ProgressScreen (ver Pathology.exerciseIds).
  final String? exerciseId;

  /// Clave = `JointDefinition.csvColumn` (hombro_izq, etc.). Una
  /// articulación puede estar ausente si nunca tuvo suficiente confianza
  /// durante toda la sesión.
  final Map<String, JointStats> jointStats;

  /// Promedio de velocidad angular (°/s, valor absoluto) por articulación —
  /// ver `SessionExporter.computeVelocityStats`. Clave = `csvColumn`, igual
  /// que `jointStats`.
  final Map<String, double> velocityStats;

  final String videoFileName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'mode': mode.name,
    'view': view.name,
    'region': region.name,
    'durationMs': durationMs,
    'sampleCount': sampleCount,
    'jointStats': jointStats.map((k, v) => MapEntry(k, v.toJson())),
    'velocityStats': velocityStats,
    'videoFileName': videoFileName,
    if (patientName != null) 'patientName': patientName,
    if (exerciseId != null) 'exerciseId': exerciseId,
  };

  factory SessionMetadata.fromJson(Map<String, dynamic> json) {
    final rawStats = json['jointStats'] as Map<String, dynamic>? ?? {};
    return SessionMetadata(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      mode: RecordingMode.values.byName(json['mode'] as String),
      // Sesiones grabadas antes de agregar la selección de vista no tienen
      // esta clave — se asumen vista frontal (equivalente al comportamiento
      // sin filtrar que tenía la app entonces).
      view: BodyView.values.byName(
        json['view'] as String? ?? BodyView.frontal.name,
      ),
      // Sesiones grabadas antes de agregar este campo no tienen esta
      // clave — se asumen `fullBody` (equivalente a no filtrar, que era el
      // comportamiento de antes).
      region: BodyRegion.values.byName(
        json['region'] as String? ?? BodyRegion.fullBody.name,
      ),
      durationMs: json['durationMs'] as int,
      sampleCount: json['sampleCount'] as int,
      jointStats: rawStats.map(
        (k, v) => MapEntry(k, JointStats.fromJson(v as Map<String, dynamic>)),
      ),
      // Sesiones grabadas antes de agregar este promedio no tienen esta
      // clave — se asume vacía (equivalente a "sin datos" en la UI).
      velocityStats: _readDoubleMap(json['velocityStats']),
      videoFileName: json['videoFileName'] as String? ?? 'video.mp4',
      patientName: json['patientName'] as String?,
      exerciseId: json['exerciseId'] as String?,
    );
  }

  static Map<String, double> _readDoubleMap(dynamic raw) {
    final map = raw as Map<String, dynamic>? ?? {};
    return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
