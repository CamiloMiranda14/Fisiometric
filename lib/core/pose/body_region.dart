import 'angle_calculator.dart';
import 'pose_landmark_type.dart';

/// Qué parte del cuerpo le interesa a un ejercicio — determina qué parte de
/// la silueta guía se dibuja (ver PositioningGuidePainter) y, durante la
/// medición en vivo, qué ángulos se calculan y qué keypoints se dibujan
/// (ver isJointActiveForRegion/isLandmarkActiveForRegion): un ejercicio de
/// tren superior no necesita calcular ni mostrar rodilla/tobillo, y
/// viceversa.
enum BodyRegion {
  /// Cabeza, torso y brazos — ejercicios de hombro/codo/muñeca.
  upperBody,

  /// Cadera y piernas — ejercicios de cadera/rodilla/tobillo.
  lowerBody,

  /// Cuerpo completo — usado cuando no hay un ejercicio específico elegido
  /// (p.ej. "Prueba rápida" desde el Home).
  fullBody,
}

/// Si el ángulo [kind] debe calcularse/mostrarse/exportarse bajo [region].
/// Cadera y rodilla son de tren inferior — el resto (hombro/codo/muñeca)
/// es de tren superior.
bool isJointActiveForRegion(JointKind kind, BodyRegion region) {
  if (region == BodyRegion.fullBody) return true;
  final isLower = switch (kind) {
    JointKind.caderaIzq ||
    JointKind.caderaDer ||
    JointKind.rodillaIzq ||
    JointKind.rodillaDer => true,
    _ => false,
  };
  return region == BodyRegion.lowerBody ? isLower : !isLower;
}

/// Landmarks exclusivos de tren superior (no se dibujan si [region] es
/// `lowerBody`) — la cadera queda fuera de ambos conjuntos a propósito:
/// es el vértice "a" tanto del ángulo de hombro como del de rodilla (ver
/// jointDefinitions), así que hace falta en las dos regiones.
const Set<PoseLandmarkType> _upperOnlyLandmarks = {
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.leftElbow,
  PoseLandmarkType.rightElbow,
  PoseLandmarkType.leftWrist,
  PoseLandmarkType.rightWrist,
  PoseLandmarkType.leftPinky,
  PoseLandmarkType.rightPinky,
  PoseLandmarkType.leftIndex,
  PoseLandmarkType.rightIndex,
  PoseLandmarkType.leftThumb,
  PoseLandmarkType.rightThumb,
};

/// Landmarks exclusivos de tren inferior (no se dibujan si [region] es
/// `upperBody`).
const Set<PoseLandmarkType> _lowerOnlyLandmarks = {
  PoseLandmarkType.leftKnee,
  PoseLandmarkType.rightKnee,
  PoseLandmarkType.leftAnkle,
  PoseLandmarkType.rightAnkle,
  PoseLandmarkType.leftHeel,
  PoseLandmarkType.rightHeel,
  PoseLandmarkType.leftFootIndex,
  PoseLandmarkType.rightFootIndex,
};

/// Si el landmark [type] debe dibujarse bajo [region] — ver SkeletonPainter.
/// Landmarks sin lado ni región definida (cadera, cara) siempre se
/// muestran.
bool isLandmarkActiveForRegion(PoseLandmarkType type, BodyRegion region) {
  if (region == BodyRegion.fullBody) return true;
  if (region == BodyRegion.upperBody) return !_lowerOnlyLandmarks.contains(type);
  return !_upperOnlyLandmarks.contains(type);
}
