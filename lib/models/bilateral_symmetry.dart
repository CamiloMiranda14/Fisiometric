import '../core/pose/angle_calculator.dart';

/// Índice de simetría bilateral (%) de los 4 pares contralaterales, en un
/// instante. Solo tiene sentido en `BodyView.frontal` — ver
/// `computeBilateralSymmetry`.
///
/// `null` significa que no se pudo calcular (algún lado del par sin ángulo
/// válido, o vista distinta a frontal) — no "simetría perfecta".
class BilateralSymmetry {
  const BilateralSymmetry({
    required this.hombro,
    required this.codo,
    required this.muneca,
    required this.rodilla,
  });

  static const empty = BilateralSymmetry(
    hombro: null,
    codo: null,
    muneca: null,
    rodilla: null,
  );

  final double? hombro;
  final double? codo;
  final double? muneca;
  final double? rodilla;

  double? forPair(SymmetricJointPair pair) {
    switch (pair) {
      case SymmetricJointPair.hombro:
        return hombro;
      case SymmetricJointPair.codo:
        return codo;
      case SymmetricJointPair.muneca:
        return muneca;
      case SymmetricJointPair.rodilla:
        return rodilla;
    }
  }

  /// Mismo orden que `symmetricJointPairs`.
  List<double?> get asOrderedList => [hombro, codo, muneca, rodilla];
}
