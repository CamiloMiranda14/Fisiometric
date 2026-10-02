/// Un ejercicio terapéutico recomendado — a diferencia de `Exercise` (que
/// mide un ángulo con la cámara y genera una sesión), estos son solo un
/// video de referencia grabado por un profesional para que el paciente lo
/// repita por su cuenta: no se graba ni se evalúa, no genera sesión ni
/// aparece en "Mi progreso".
class RecommendedExercise {
  const RecommendedExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.videoAssetPath,
    this.requirementExerciseId,
    this.requirementMinRom,
  });

  final String id;
  final String name;
  final String description;
  final String videoAssetPath;

  /// Si no es `null`, este ejercicio es de fase avanzada y solo se
  /// desbloquea cuando el paciente ya alcanzó [requirementMinRom]° (misma
  /// convención "0° = extendido, sube con la flexión" que usa
  /// `JointAngles.fromPoseFrame`) en alguna sesión guardada del ejercicio de
  /// medición [requirementExerciseId] (un id de `exerciseCatalog`) — ver
  /// RecommendedExerciseScreen, que revisa las sesiones del paciente antes
  /// de dejarlo verlo/empezarlo. `null` en ambos campos significa "sin
  /// requisito", como todos los ejercicios recomendados hasta ahora.
  final String? requirementExerciseId;
  final double? requirementMinRom;
}
