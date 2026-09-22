import 'dart:math' as math;

import '../../models/pose_landmark.dart';
import 'pose_landmark_type.dart';

/// Confianza mínima para considerar un landmark "visible". Por debajo de
/// este umbral, cualquier ángulo que lo involucre se reporta como `null`
/// (celda vacía en el CSV, "—" en el HUD) y el hueso correspondiente no
/// se dibuja en el esqueleto.
const double kMinLandmarkVisibility = 0.5;

/// Ángulo interior en [vertex], entre los vectores hacia [a] y [c] — igual a
/// como mide un goniómetro físico (180° = articulación extendida).
///
/// Recibe landmarks ya en espacio de píxeles (ver [PoseLandmark]): si se le
/// pasaran coordenadas normalizadas 0-1 de una imagen no cuadrada, el
/// resultado quedaría sesgado por el aspect ratio.
double angleAtVertex(PoseLandmark a, PoseLandmark vertex, PoseLandmark c) {
  final v1x = a.x - vertex.x;
  final v1y = a.y - vertex.y;
  final v2x = c.x - vertex.x;
  final v2y = c.y - vertex.y;

  final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
  final mag2 = math.sqrt(v2x * v2x + v2y * v2y);
  if (mag1 == 0 || mag2 == 0) return double.nan;

  final cosAngle = ((v1x * v2x + v1y * v2y) / (mag1 * mag2)).clamp(-1.0, 1.0);
  return math.acos(cosAngle) * 180 / math.pi;
}

/// Identifica cada una de las 10 articulaciones medidas por la app.
enum JointKind {
  hombroIzq,
  hombroDer,
  codoIzq,
  codoDer,
  munecaIzq,
  munecaDer,
  caderaIzq,
  caderaDer,
  rodillaIzq,
  rodillaDer,
}

/// Define un ángulo articular como el triple (puntoA, vértice, puntoC) que
/// lo forma, más la etiqueta a mostrar en el HUD/esqueleto y la columna
/// (snake_case) a usar en el CSV/session.json exportados.
class JointDefinition {
  const JointDefinition({
    required this.kind,
    required this.a,
    required this.vertex,
    required this.c,
    required this.label,
    required this.csvColumn,
  });

  final JointKind kind;
  final PoseLandmarkType a;
  final PoseLandmarkType vertex;
  final PoseLandmarkType c;
  final String label;
  final String csvColumn;
}

/// Las 10 articulaciones medidas. `muneca_*` es una aproximación más burda
/// que las otras: BlazePose no tiene un eje de mano real, solo 3 puntos
/// base de dedos (17-22), así que se usa el landmark de índice como
/// segundo brazo del ángulo. `cadera_*` usa el hombro como referencia
/// proximal (igual que `rodilla_*` usa la cadera) — 180° con el paciente de
/// pie (hombro-cadera-rodilla casi en línea recta), decreciendo al
/// flexionar la cadera, misma convención "goniómetro" que codo/rodilla.
///
/// Esa es la salida CRUDA de [angleAtVertex] — `JointAngles.fromPoseFrame`
/// la convierte para todo lo demás (HUD en vivo, esqueleto, CSV exportado,
/// gráficas) a "0° = extendido, sube con la flexión" para codo/muñeca/
/// cadera/rodilla, ver el comentario ahí.
const List<JointDefinition> jointDefinitions = [
  JointDefinition(
    kind: JointKind.hombroIzq,
    a: PoseLandmarkType.leftHip,
    vertex: PoseLandmarkType.leftShoulder,
    c: PoseLandmarkType.leftElbow,
    label: 'Hombro izq.',
    csvColumn: 'hombro_izq',
  ),
  JointDefinition(
    kind: JointKind.hombroDer,
    a: PoseLandmarkType.rightHip,
    vertex: PoseLandmarkType.rightShoulder,
    c: PoseLandmarkType.rightElbow,
    label: 'Hombro der.',
    csvColumn: 'hombro_der',
  ),
  JointDefinition(
    kind: JointKind.codoIzq,
    a: PoseLandmarkType.leftShoulder,
    vertex: PoseLandmarkType.leftElbow,
    c: PoseLandmarkType.leftWrist,
    label: 'Codo izq.',
    csvColumn: 'codo_izq',
  ),
  JointDefinition(
    kind: JointKind.codoDer,
    a: PoseLandmarkType.rightShoulder,
    vertex: PoseLandmarkType.rightElbow,
    c: PoseLandmarkType.rightWrist,
    label: 'Codo der.',
    csvColumn: 'codo_der',
  ),
  JointDefinition(
    kind: JointKind.munecaIzq,
    a: PoseLandmarkType.leftElbow,
    vertex: PoseLandmarkType.leftWrist,
    c: PoseLandmarkType.leftIndex,
    label: 'Muñeca izq.',
    csvColumn: 'muneca_izq',
  ),
  JointDefinition(
    kind: JointKind.munecaDer,
    a: PoseLandmarkType.rightElbow,
    vertex: PoseLandmarkType.rightWrist,
    c: PoseLandmarkType.rightIndex,
    label: 'Muñeca der.',
    csvColumn: 'muneca_der',
  ),
  JointDefinition(
    kind: JointKind.caderaIzq,
    a: PoseLandmarkType.leftShoulder,
    vertex: PoseLandmarkType.leftHip,
    c: PoseLandmarkType.leftKnee,
    label: 'Cadera izq.',
    csvColumn: 'cadera_izq',
  ),
  JointDefinition(
    kind: JointKind.caderaDer,
    a: PoseLandmarkType.rightShoulder,
    vertex: PoseLandmarkType.rightHip,
    c: PoseLandmarkType.rightKnee,
    label: 'Cadera der.',
    csvColumn: 'cadera_der',
  ),
  JointDefinition(
    kind: JointKind.rodillaIzq,
    a: PoseLandmarkType.leftHip,
    vertex: PoseLandmarkType.leftKnee,
    c: PoseLandmarkType.leftAnkle,
    label: 'Rodilla izq.',
    csvColumn: 'rodilla_izq',
  ),
  JointDefinition(
    kind: JointKind.rodillaDer,
    a: PoseLandmarkType.rightHip,
    vertex: PoseLandmarkType.rightKnee,
    c: PoseLandmarkType.rightAnkle,
    label: 'Rodilla der.',
    csvColumn: 'rodilla_der',
  ),
];

/// Pares izq/der de las 4 articulaciones, en el mismo orden que sus filas
/// en el HUD (vista frontal). Puramente de layout — ya no implica ningún
/// cálculo entre lados (ver decisión de quitar la simetría bilateral: la
/// app ya no evalúa si un ejercicio se ejecutó "correctamente" comparando
/// lados, sino el progreso de una articulación con movimiento limitado).
const List<(JointKind, JointKind)> jointPairs = [
  (JointKind.hombroIzq, JointKind.hombroDer),
  (JointKind.codoIzq, JointKind.codoDer),
  (JointKind.munecaIzq, JointKind.munecaDer),
  (JointKind.caderaIzq, JointKind.caderaDer),
  (JointKind.rodillaIzq, JointKind.rodillaDer),
];

/// Pares de landmarks a dibujar como "huesos" del esqueleto. Incluye más
/// segmentos que los estrictamente necesarios para los ángulos (p.ej.
/// hombro-hombro, cadera-cadera) para que la figura sea reconocible.
const List<(PoseLandmarkType, PoseLandmarkType)> skeletonBones = [
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
  (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
  (PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex),
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
  (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
  (PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex),
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
  (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
  (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
  (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
  (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
  (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
];
