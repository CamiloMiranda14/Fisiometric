import '../core/pose/angle_calculator.dart';

/// Velocidad angular de las 10 articulaciones en un instante, en °/s.
///
/// `null` significa que no se pudo calcular (sin frame anterior válido, o
/// el ángulo actual/anterior de esa articulación era `null`) — no "velocidad
/// cero".
class JointAngularVelocity {
  const JointAngularVelocity({
    required this.hombroIzq,
    required this.hombroDer,
    required this.codoIzq,
    required this.codoDer,
    required this.munecaIzq,
    required this.munecaDer,
    required this.caderaIzq,
    required this.caderaDer,
    required this.rodillaIzq,
    required this.rodillaDer,
  });

  static const empty = JointAngularVelocity(
    hombroIzq: null,
    hombroDer: null,
    codoIzq: null,
    codoDer: null,
    munecaIzq: null,
    munecaDer: null,
    caderaIzq: null,
    caderaDer: null,
    rodillaIzq: null,
    rodillaDer: null,
  );

  final double? hombroIzq;
  final double? hombroDer;
  final double? codoIzq;
  final double? codoDer;
  final double? munecaIzq;
  final double? munecaDer;
  final double? caderaIzq;
  final double? caderaDer;
  final double? rodillaIzq;
  final double? rodillaDer;

  double? forJoint(JointKind kind) {
    switch (kind) {
      case JointKind.hombroIzq:
        return hombroIzq;
      case JointKind.hombroDer:
        return hombroDer;
      case JointKind.codoIzq:
        return codoIzq;
      case JointKind.codoDer:
        return codoDer;
      case JointKind.munecaIzq:
        return munecaIzq;
      case JointKind.munecaDer:
        return munecaDer;
      case JointKind.caderaIzq:
        return caderaIzq;
      case JointKind.caderaDer:
        return caderaDer;
      case JointKind.rodillaIzq:
        return rodillaIzq;
      case JointKind.rodillaDer:
        return rodillaDer;
    }
  }

  /// Mismo orden que las columnas del CSV — ver SessionExporter.
  List<double?> get asOrderedList => [
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
  ];
}
