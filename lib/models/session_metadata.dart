import 'dart:convert';

import '../core/pose/angle_calculator.dart';
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
    this.unreliableJoints = const {},
    this.plateauedJoints = const {},
    this.recordedByTherapist = false,
    this.trackedJoints,
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

  /// Columnas (`csvColumn`) donde una parte importante de las lecturas
  /// crudas superó el límite biomecánico plausible de esa articulación —
  /// señal de que el detector probablemente perdió el punto real durante
  /// buena parte de la sesión, ver `SessionExporter.computeUnreliableJoints`.
  /// Vacío en sesiones grabadas antes de agregar este chequeo.
  final Set<String> unreliableJoints;

  /// Columnas donde el paciente parece haber sostenido una posición
  /// cercana a su máximo al final de la sesión (en vez de seguir subiendo
  /// justo cuando terminó la grabación) — señal de que ese intento sí
  /// refleja su rango real de ese día, ver
  /// `SessionExporter.computePlateauedJoints`. Vacío en sesiones grabadas
  /// antes de agregar este chequeo.
  final Set<String> plateauedJoints;

  /// `true` si la grabó un fisioterapeuta (cámara trasera, "Modo
  /// fisioterapeuta") en vez del propio paciente — permite distinguir estas
  /// mediciones de las de seguimiento diario en casa. `false` en sesiones
  /// grabadas antes de agregar este modo.
  final bool recordedByTherapist;

  /// Qué articulación(es) se restringió esta sesión en particular (ver
  /// `Exercise.trackedJoints` ya ajustado al lado del paciente con
  /// `forPatientSide`) — `null` sin restricción más allá de región/vista
  /// ("Prueba rápida: todas", o sesiones grabadas antes de agregar este
  /// campo).
  ///
  /// Se guarda explícito en vez de recalcularlo desde `exerciseId` cada vez
  /// que hace falta (ver `trackedJointsForExerciseId`) porque ESE ejercicio
  /// del catálogo no sabe de qué lado es el paciente — recalcularlo así
  /// devuelve el ejercicio SIN restringir (ambos lados), justo el bug que
  /// esto corrige: medir cadera derecha mostraba también el cálculo de
  /// cadera izquierda al repetir la medición, porque "Repetir" reconstruía
  /// la pantalla de grabación solo con el `exerciseId`, perdiendo la
  /// restricción de lado ya resuelta la primera vez.
  final Set<JointKind>? trackedJoints;

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
    if (unreliableJoints.isNotEmpty) 'unreliableJoints': unreliableJoints.toList(),
    if (plateauedJoints.isNotEmpty) 'plateauedJoints': plateauedJoints.toList(),
    if (recordedByTherapist) 'recordedByTherapist': recordedByTherapist,
    if (trackedJoints != null) 'trackedJoints': trackedJoints!.map((k) => k.name).toList(),
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
      unreliableJoints:
          (json['unreliableJoints'] as List<dynamic>?)?.cast<String>().toSet() ?? const {},
      plateauedJoints:
          (json['plateauedJoints'] as List<dynamic>?)?.cast<String>().toSet() ?? const {},
      recordedByTherapist: json['recordedByTherapist'] as bool? ?? false,
      trackedJoints: (json['trackedJoints'] as List<dynamic>?)
          ?.map((name) => JointKind.values.byName(name as String))
          .toSet(),
    );
  }

  static Map<String, double> _readDoubleMap(dynamic raw) {
    final map = raw as Map<String, dynamic>? ?? {};
    return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
