import '../../models/joint_angles.dart';
import '../../models/joint_angular_velocity.dart';
import 'angle_calculator.dart';

/// A partir de cuántos °/s se considera que el paciente está moviendo la
/// articulación "demasiado rápido" (ver MeasurementController.isMovingTooFast
/// — aviso en vivo durante la grabación). No viene de ningún valor clínico
/// documentado por patología (`patologias_objetivo.docx`/`caderas.docx` no
/// especifican una velocidad máxima) — es un valor de partida razonable
/// para detectar un movimiento brusco/descontrolado; ajustar si en la
/// práctica avisa de más o de menos.
const double kFastMovementThresholdDegPerSec = 120;

/// Cuántas lecturas recientes de velocidad se promedian antes de comparar
/// contra el umbral — sin esto, el ruido frame-a-frame (ver comentario de
/// [computeAngularVelocity]) haría que el aviso parpadee prendido/apagado
/// en vez de reaccionar de forma estable a un movimiento realmente rápido.
const int kVelocitySmoothingWindow = 5;

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
    caderaIzq: values[JointKind.caderaIzq],
    caderaDer: values[JointKind.caderaDer],
    rodillaIzq: values[JointKind.rodillaIzq],
    rodillaDer: values[JointKind.rodillaDer],
  );
}
