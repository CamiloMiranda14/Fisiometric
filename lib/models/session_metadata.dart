import 'dart:convert';

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
    required this.durationMs,
    required this.sampleCount,
    required this.jointStats,
    required this.videoFileName,
  });

  final String id;
  final DateTime startedAt;
  final RecordingMode mode;
  final int durationMs;
  final int sampleCount;

  /// Clave = `JointDefinition.csvColumn` (hombro_izq, etc.). Una
  /// articulación puede estar ausente si nunca tuvo suficiente confianza
  /// durante toda la sesión.
  final Map<String, JointStats> jointStats;

  final String videoFileName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'mode': mode.name,
    'durationMs': durationMs,
    'sampleCount': sampleCount,
    'jointStats': jointStats.map((k, v) => MapEntry(k, v.toJson())),
    'videoFileName': videoFileName,
  };

  factory SessionMetadata.fromJson(Map<String, dynamic> json) {
    final rawStats = json['jointStats'] as Map<String, dynamic>? ?? {};
    return SessionMetadata(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      mode: RecordingMode.values.byName(json['mode'] as String),
      durationMs: json['durationMs'] as int,
      sampleCount: json['sampleCount'] as int,
      jointStats: rawStats.map(
        (k, v) => MapEntry(k, JointStats.fromJson(v as Map<String, dynamic>)),
      ),
      videoFileName: json['videoFileName'] as String? ?? 'video.mp4',
    );
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
