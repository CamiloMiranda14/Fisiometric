import 'angle_calculator.dart';
import 'pose_landmark_type.dart';

/// Vista de cámara elegida por el usuario antes de grabar una sesión.
///
/// En `izquierda`/`derecha` (vista lateral típica de una evaluación de
/// fisioterapia), el lado del cuerpo opuesto a la cámara suele quedar
/// parcialmente oculto: el detector igual reporta landmarks para ese lado,
/// pero con posición/confianza poco fiable. `isJointActiveForView` se usa
/// para anular explícitamente ese lado (no calcularlo ni exportarlo) en vez
/// de confiar en el umbral de visibilidad del detector.
enum BodyView {
  frontal,
  izquierda,
  derecha;

  String get label => switch (this) {
    BodyView.frontal => 'Vista frontal',
    BodyView.izquierda => 'Vista izquierda',
    BodyView.derecha => 'Vista derecha',
  };
}

/// Si [kind] debe calcularse/mostrarse/exportarse bajo la vista [view].
bool isJointActiveForView(JointKind kind, BodyView view) {
  if (view == BodyView.frontal) return true;

  final isIzq = switch (kind) {
    JointKind.hombroIzq ||
    JointKind.codoIzq ||
    JointKind.munecaIzq ||
    JointKind.rodillaIzq => true,
    JointKind.hombroDer ||
    JointKind.codoDer ||
    JointKind.munecaDer ||
    JointKind.rodillaDer => false,
  };

  return view == BodyView.izquierda ? isIzq : !isIzq;
}

/// Si el landmark [type] (punto del esqueleto, no un ángulo) debe
/// dibujarse bajo la vista [view]. Se usa para el esqueleto dibujado sobre
/// la cámara (SkeletonPainter) — a diferencia de [isJointActiveForView],
/// que solo cubre los 8 ángulos medidos, esto cubre cualquier landmark
/// (hombro, codo, muñeca, cadera, rodilla, tobillo, etc.). Landmarks sin
/// lado (p.ej. `nose`) siempre se muestran.
bool isLandmarkActiveForView(PoseLandmarkType type, BodyView view) {
  if (view == BodyView.frontal) return true;

  final name = type.name;
  if (name.startsWith('left')) return view == BodyView.izquierda;
  if (name.startsWith('right')) return view == BodyView.derecha;
  return true;
}
