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
        'De pie, apoya el brazo estirado sobre una superficie elevada (una '
        'silla, una mesa o un mueble firme) e inclínate despacio hacia '
        'adelante, dejando que el hombro se estire hacia arriba. Sostén '
        'unos segundos y vuelve. Fase de movilidad para ganar más rango de '
        'flexión sin forzar.',
    videoAssetPath: 'assets/exercises/recomendados/estiramiento_flexion_hombro.mp4',
  ),
  RecommendedExercise(
    id: 'abduccion_activa_hombro',
    name: 'Abducción activa de hombro con peso liviano',
    description:
        'De pie, con un peso liviano en la mano (una botella de agua '
        'sirve), eleva el brazo hacia el lado hasta la altura del hombro y '
        'bájalo despacio, controlando el movimiento en todo momento. Fase '
        'avanzada de fortalecimiento activo, con carga, a diferencia de '
        'un estiramiento pasivo.',
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
        'De pie, con un peso liviano en la mano (una botella de agua '
        'sirve), flexiona el codo llevando la mano hacia el hombro y '
        'bájala despacio, controlando el movimiento en todo momento. Fase '
        'avanzada de fortalecimiento activo, con la fijación de la '
        'fractura de cúbito/radio ya consolidada.',
    videoAssetPath: 'assets/exercises/recomendados/flexion_activa_codo.mp4',
  ),
  RecommendedExercise(
    id: 'sentadilla_asistida_rodilla',
    name: 'Mini sentadilla asistida',
    description:
        'De pie, sosteniéndote de un apoyo firme para el equilibrio, baja '
        'en una sentadilla corta y controlada, sin pasar de un rango '
        'cómodo, y vuelve a subir despacio. Fase de fortalecimiento '
        'funcional, después de recuperar la movilidad básica de la '
        'rodilla.',
    videoAssetPath: 'assets/exercises/recomendados/sentadilla_asistida_rodilla.mp4',
  ),
  RecommendedExercise(
    id: 'abduccion_sentada_cadera',
    name: 'Abducción de cadera sentado',
    description:
        'Siéntate en el piso con las manos apoyadas atrás para sostenerte '
        'y desliza la pierna afectada hacia un lado, alejándola de la '
        'línea media del cuerpo, dentro de un rango cómodo y sin dolor, '
        'luego regrésala. Trabaja la abducción de cadera de forma suave y '
        'controlada.',
    videoAssetPath: 'assets/exercises/recomendados/deslizamiento_sentado_cadera.mp4',
  ),
  RecommendedExercise(
    id: 'sentadilla_sumo_cadera',
    name: 'Mini sentadilla sumo',
    description:
        'De pie, con los pies más separados que el ancho de los hombros y '
        'las puntas ligeramente hacia afuera, baja en una sentadilla '
        'corta y controlada, sin pasar de un rango cómodo, y vuelve a '
        'subir. Fase avanzada de fortalecimiento de glúteos y cuádriceps.',
    videoAssetPath: 'assets/exercises/recomendados/sentadilla_sumo_cadera.mp4',
  ),
];
