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
  });

  final String id;
  final String name;
  final String description;
  final String videoAssetPath;
}
