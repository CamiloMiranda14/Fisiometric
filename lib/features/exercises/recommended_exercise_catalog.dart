import '../../models/recommended_exercise.dart';

/// Catálogo "de fábrica" de ejercicios terapéuticos recomendados — uno por
/// patología, tomado de la fase inicial de su protocolo de tratamiento
/// (ver `patologias_objetivo.docx`, "Tratamiento post-quirúrgico"). A
/// diferencia de `exerciseCatalog` (las mediciones de rango de
/// movimiento), estos no se graban ni se evalúan.
///
/// Faltan los videos reales en `assets/exercises/recomendados/` con estos
/// mismos nombres de archivo — mientras tanto RecommendedExerciseScreen
/// muestra un aviso en vez de reventar si el archivo no está.
const List<RecommendedExercise> recommendedExerciseCatalog = [
  RecommendedExercise(
    id: 'pendulos_codman',
    name: 'Péndulos de Codman',
    description:
        'Inclínate hacia adelante apoyando la mano sana en una mesa o silla, '
        'deja el brazo afectado colgar relajado y balancéalo suavemente en '
        'pequeños círculos y de adelante hacia atrás. Fase inicial post-fractura '
        'de húmero — solo movilización pasiva, sin forzar el rango.',
    videoAssetPath: 'assets/exercises/recomendados/pendulos_codman.mp4',
  ),
  RecommendedExercise(
    id: 'movilizacion_asistida_hombro',
    name: 'Movilización pendular y asistida de hombro',
    description:
        'Con el brazo relajado, ayúdate con la mano sana para mover el hombro '
        'afectado suavemente dentro del rango libre de dolor. Fase inicial de '
        'capsulitis adhesiva — movilización pasiva y activo-asistida, sin '
        'forzar hacia el dolor.',
    videoAssetPath: 'assets/exercises/recomendados/movilizacion_asistida_hombro.mp4',
  ),
  RecommendedExercise(
    id: 'movilidad_dedos_muneca',
    name: 'Movilidad de dedos y muñeca',
    description:
        'Abre y cierra la mano, y mueve la muñeca hacia arriba/abajo dentro '
        'de un rango cómodo. Fase inicial post-fractura de cúbito/radio, '
        'mientras el codo sigue inmovilizado — mantiene la movilidad de dedos '
        'y muñeca sin comprometer la fijación quirúrgica.',
    videoAssetPath: 'assets/exercises/recomendados/movilidad_dedos_muneca.mp4',
  ),
  RecommendedExercise(
    id: 'extension_activa_rodilla',
    name: 'Extensión activa de rodilla',
    description:
        'Sentado, con la pierna extendida sobre una superficie firme, '
        'contrae el músculo del muslo para presionar la parte de atrás de la '
        'rodilla contra la superficie. Fase inicial post-LCA — el objetivo '
        'clínico más importante de la primera semana es recuperar la '
        'extensión completa.',
    videoAssetPath: 'assets/exercises/recomendados/extension_activa_rodilla.mp4',
  ),
  RecommendedExercise(
    id: 'flexion_asistida_rodilla',
    name: 'Flexión asistida de rodilla (hasta 90°)',
    description:
        'Sentado al borde de una silla o cama, desliza el talón hacia atrás '
        'para flexionar la rodilla suavemente, sin pasar de 90° en las '
        'primeras semanas. Fase inicial post-meniscectomía/reparación de '
        'menisco.',
    videoAssetPath: 'assets/exercises/recomendados/flexion_asistida_rodilla.mp4',
  ),
  RecommendedExercise(
    id: 'movilidad_articular_cadera',
    name: 'Movilidad articular de cadera',
    description:
        'Acostado boca arriba, desliza el talón hacia el glúteo para '
        'flexionar la cadera y luego estira la pierna hacia un lado dentro '
        'de un rango cómodo, sin dolor. Combínalo con ejercicios de '
        'fortalecimiento de glúteos y cuádriceps. Para coxartrosis — mejora '
        'la movilidad articular y ayuda a controlar el peso sobre la '
        'articulación.',
    videoAssetPath: 'assets/exercises/recomendados/movilidad_articular_cadera.mp4',
  ),
  RecommendedExercise(
    id: 'abduccion_activa_hombro',
    name: 'Abducción activa de hombro con peso liviano',
    description:
        'De pie, con un peso liviano en la mano (una botella de agua '
        'sirve), eleva el brazo hacia el lado hasta la altura del hombro y '
        'bájalo despacio, controlando el movimiento en todo momento. Fase '
        'avanzada de fortalecimiento activo, con carga — a diferencia de '
        'los ejercicios de movilización pasiva/asistida de las fases '
        'iniciales.',
    videoAssetPath: 'assets/exercises/recomendados/abduccion_activa_hombro.mp4',
    // El requisito es del MISMO movimiento que este ejercicio progresa
    // (abducción, con carga) — no de flexión, que es un movimiento
    // distinto y no dice nada sobre si el paciente ya tiene suficiente
    // abducción activa/pasiva como para agregarle peso.
    requirementExerciseId: 'hombro_abduccion_frontal',
    requirementMinRom: 90,
  ),
  RecommendedExercise(
    id: 'movilizacion_pasiva_cadera',
    name: 'Movilización pasiva y activo-asistida de cadera',
    description:
        'Acostado boca arriba, con ayuda de otra persona o de tus manos, '
        'flexiona suavemente la cadera afectada sin pasar de 70° y sin '
        'forzar. Acompaña con contracciones isométricas de cuádriceps y '
        'glúteos (tensa el músculo sin mover la articulación). Fase inicial '
        '(semanas 0-4) post-fractura de cadera con osteosíntesis — respeta '
        'la restricción de carga que te haya indicado tu médico.',
    videoAssetPath: 'assets/exercises/recomendados/movilizacion_pasiva_cadera.mp4',
  ),
];
