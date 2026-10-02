import '../../core/pose/angle_calculator.dart';
import '../../core/pose/body_region.dart';

/// Qué articulación medir cuando se elige libremente (no viene fija por un
/// `Exercise.trackedJoints`) — usado en "Prueba rápida" y en "Modo
/// fisioterapeuta".
enum JointChoice { hombro, codo, muneca, cadera, rodilla, todas }

extension JointChoiceX on JointChoice {
  String get label => switch (this) {
    JointChoice.hombro => 'Hombro',
    JointChoice.codo => 'Codo',
    JointChoice.muneca => 'Muñeca',
    JointChoice.cadera => 'Cadera',
    JointChoice.rodilla => 'Rodilla',
    JointChoice.todas => 'Todas (cuerpo completo)',
  };

  /// `null` = no restringe articulaciones (caso "todas").
  Set<JointKind>? get trackedJoints => switch (this) {
    JointChoice.hombro => const {JointKind.hombroIzq, JointKind.hombroDer},
    JointChoice.codo => const {JointKind.codoIzq, JointKind.codoDer},
    JointChoice.muneca => const {JointKind.munecaIzq, JointKind.munecaDer},
    JointChoice.cadera => const {JointKind.caderaIzq, JointKind.caderaDer},
    JointChoice.rodilla => const {JointKind.rodillaIzq, JointKind.rodillaDer},
    JointChoice.todas => null,
  };

  BodyRegion get region => switch (this) {
    JointChoice.hombro || JointChoice.codo || JointChoice.muneca => BodyRegion.upperBody,
    JointChoice.cadera || JointChoice.rodilla => BodyRegion.lowerBody,
    JointChoice.todas => BodyRegion.fullBody,
  };
}
