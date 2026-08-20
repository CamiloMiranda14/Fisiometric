import 'dart:convert';

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
    required this.durationMs,
    required this.sampleCount,
    required this.jointStats,
    required this.velocityStats,
    required this.symmetryStats,
    required this.videoFileName,
  });

  final String id;
  final DateTime startedAt;
  final RecordingMode mode;
  final BodyView view;
  final int durationMs;
  final int sampleCount;

  /// Clave = `JointDefinition.csvColumn` (hombro_izq, etc.). Una
  /// articulación puede estar ausente si nunca tuvo suficiente confianza
  /// durante toda la sesión.
  final Map<String, JointStats> jointStats;

  /// Promedio de velocidad angular (°/s, valor absoluto) por articulación —
  /// ver `SessionExporter.computeVelocityStats`. Clave = `csvColumn`, igual
  /// que `jointStats`.
  final Map<String, double> velocityStats;

  /// Promedio de simetría bilateral (SI %) por par de articulaciones — ver
  /// `SessionExporter.computeSymmetryStats`. Vacío fuera de
  /// `BodyView.frontal`. Clave = `SymmetricPairDefinition.csvColumn`.
  final Map<String, double> symmetryStats;

  final String videoFileName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'mode': mode.name,
    'view': view.name,
    'durationMs': durationMs,
    'sampleCount': sampleCount,
    'jointStats': jointStats.map((k, v) => MapEntry(k, v.toJson())),
    'velocityStats': velocityStats,
    'symmetryStats': symmetryStats,
    'videoFileName': videoFileName,
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
      durationMs: json['durationMs'] as int,
      sampleCount: json['sampleCount'] as int,
      jointStats: rawStats.map(
        (k, v) => MapEntry(k, JointStats.fromJson(v as Map<String, dynamic>)),
      ),
      // Sesiones grabadas antes de agregar estos promedios no tienen estas
      // claves — se asumen vacías (equivalente a "sin datos" en la UI).
      velocityStats: _readDoubleMap(json['velocityStats']),
      symmetryStats: _readDoubleMap(json['symmetryStats']),
      videoFileName: json['videoFileName'] as String? ?? 'video.mp4',
    );
  }

  static Map<String, double> _readDoubleMap(dynamic raw) {
    final map = raw as Map<String, dynamic>? ?? {};
    return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
