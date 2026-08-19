import '../../models/bilateral_symmetry.dart';
import '../../models/joint_angles.dart';
import 'angle_calculator.dart';

/// Índice de simetría bilateral clásico por par contralateral:
/// `SI = |L - R| / (0.5 * (L + R)) * 100`, en %. 0% = simetría perfecta.
///
/// Solo es significativo cuando ambos lados del par vienen de la misma
/// vista frontal — con `JointAngles` ya filtrado por `BodyView.izquierda`/
/// `derecha` (ver `JointAngles.filterForView`), un lado siempre es `null` y
/// esta función retorna `BilateralSymmetry.empty` sola; el llamador
/// (`MeasurementController`) igual gatea explícitamente por vista para que
/// la intención quede clara en el sitio de la llamada.
BilateralSymmetry computeBilateralSymmetry(JointAngles angles) {
  double? symmetryFor(SymmetricJointPair pair) {
    final def = symmetricJointPairs.firstWhere((d) => d.pair == pair);
    final l = angles.forJoint(def.izq);
    final r = angles.forJoint(def.der);
    if (l == null || r == null) return null;
    final denominator = 0.5 * (l + r);
    if (denominator == 0) return null;
    return (l - r).abs() / denominator * 100;
  }

  final values = <SymmetricJointPair, double?>{
    for (final pair in SymmetricJointPair.values) pair: symmetryFor(pair),
  };

  return BilateralSymmetry(
    hombro: values[SymmetricJointPair.hombro],
    codo: values[SymmetricJointPair.codo],
    muneca: values[SymmetricJointPair.muneca],
    rodilla: values[SymmetricJointPair.rodilla],
  );
}
