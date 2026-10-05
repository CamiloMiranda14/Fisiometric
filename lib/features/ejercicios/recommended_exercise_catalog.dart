import '../../modelos/recommended_exercise.dart';

/// Catálogo de ejercicios terapéuticos recomendados — a diferencia de
/// `exerciseCatalog` (las mediciones de rango de movimiento), estos no se
/// graban ni se evalúan, son videos de referencia para repetir por cuenta
/// propia. Cada uno tiene su video real en `assets/exercises/recomendados/`
/// (a propósito no hay entradas "de relleno" sin video todavía).
const List<RecommendedExercise> recommendedExerciseCatalog = [
  RecommendedExercise(
    id: 'estiramiento_flexion_hombro',
    name: 'Estiramiento de flexión de hombro con apoyo',
    description:
        'Apoya el brazo estirado sobre algo firme (una silla, una mesa o '
        'un mueble a buena altura) e inclínate despacio hacia adelante, '
        'sintiendo cómo se estira el hombro hacia arriba, como en el '
        'video. Sostén unos segundos y vuelve, sin forzar ni llegar a '
        'sentir dolor.',
    videoAssetPath:
        'assets/exercises/recomendados/estiramiento_flexion_hombro.mp4',
  ),
  RecommendedExercise(
    id: 'abduccion_activa_hombro',
    name: 'Abducción activa de hombro con peso liviano',
    description:
        'Con un peso liviano en la mano (por ejemplo, una botella de '
        'agua), levanta el brazo hacia el lado hasta la altura del '
        'hombro y bájalo despacio, sin dejar que caiga de golpe. '
        'Guíate por el ritmo y la altura que muestra el video.',
    videoAssetPath: 'assets/exercises/recomendados/abduccion_activa_hombro.mp4',
    // El requisito es del MISMO movimiento que este ejercicio progresa
    // (abducción, con carga), no de flexión: solo se desbloquea cuando el
    // paciente ya mide al menos 90° de abducción real.
    requirementExerciseId: 'hombro_abduccion_frontal',
    requirementMinRom: 90,
  ),
  RecommendedExercise(
    id: 'flexion_activa_codo',
    name: 'Flexión activa de codo con peso liviano',
    description:
        'Con un peso liviano en la mano (por ejemplo, una botella de '
        'agua), dobla el codo llevando la mano hacia el hombro y bájala '
        'despacio, sin dejar que caiga de golpe. Sigue el ritmo que ves '
        'en el video.',
    videoAssetPath: 'assets/exercises/recomendados/flexion_activa_codo.mp4',
  ),
  RecommendedExercise(
    id: 'sentadilla_asistida_rodilla',
    name: 'Mini sentadilla asistida',
    description:
        'Sostente de algo firme para el equilibrio (una silla o una '
        'baranda), baja en una sentadilla corta y despacio, solo hasta '
        'donde te sientas cómodo, y vuelve a subir. Guíate por el video '
        'para ver qué tan abajo llegar.',
    videoAssetPath:
        'assets/exercises/recomendados/sentadilla_asistida_rodilla.mp4',
  ),
  RecommendedExercise(
    id: 'abduccion_sentada_cadera',
    name: 'Abducción de cadera sentado',
    description:
        'Siéntate en el piso con las manos apoyadas atrás para '
        'sostenerte y desliza la pierna afectada hacia un lado, '
        'alejándola del cuerpo, dentro de un rango cómodo y sin dolor. '
        'Luego regrésala despacio, como en el video.',
    videoAssetPath:
        'assets/exercises/recomendados/deslizamiento_sentado_cadera.mp4',
  ),
  RecommendedExercise(
    id: 'sentadilla_sumo_cadera',
    name: 'Mini sentadilla sumo',
    description:
        'Con los pies más separados que el ancho de tus hombros y las '
        'puntas apuntando un poco hacia afuera, baja en una sentadilla '
        'corta y despacio, solo hasta donde te sientas cómodo, y vuelve '
        'a subir, siguiendo el ritmo del video.',
    videoAssetPath: 'assets/exercises/recomendados/sentadilla_sumo_cadera.mp4',
  ),
];
