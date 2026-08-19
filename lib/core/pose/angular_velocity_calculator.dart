import '../../models/joint_angles.dart';
import '../../models/joint_angular_velocity.dart';
import 'angle_calculator.dart';

/// Velocidad angular por diferencia simple entre dos lecturas consecutivas
/// de [JointAngles], sin ventana de suavizado: reacciona de inmediato a
/// cada frame, a costa de heredar el ruido frame-a-frame del detector.
JointAngularVelocity computeAngularVelocity({
  required JointAngles previous,
  required JointAngles current,
  required int dtMs,
}) {
  if (dtMs <= 0) return JointAngularVelocity.empty;

  final dtSeconds = dtMs / 1000;

  double? velocityFor(JointKind kind) {
    final prevAngle = previous.forJoint(kind);
    final currAngle = current.forJoint(kind);
    if (prevAngle == null || currAngle == null) return null;
    return (currAngle - prevAngle) / dtSeconds;
  }

  final values = <JointKind, double?>{
    for (final kind in JointKind.values) kind: velocityFor(kind),
  };

  return JointAngularVelocity(
    hombroIzq: values[JointKind.hombroIzq],
    hombroDer: values[JointKind.hombroDer],
    codoIzq: values[JointKind.codoIzq],
    codoDer: values[JointKind.codoDer],
    munecaIzq: values[JointKind.munecaIzq],
    munecaDer: values[JointKind.munecaDer],
    rodillaIzq: values[JointKind.rodillaIzq],
    rodillaDer: values[JointKind.rodillaDer],
  );
}
