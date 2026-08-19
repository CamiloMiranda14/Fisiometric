import 'angle_calculator.dart';

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
