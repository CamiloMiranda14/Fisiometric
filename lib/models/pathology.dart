/// Las 7 patologías objetivo del sistema (ver `patologias_objetivo.docx` y
/// `caderas.docx`, este último agregado después). Cada una determina qué
/// ejercicio(s) del catálogo le corresponden al paciente (ver
/// [exerciseIds]) — ProgressScreen muestra un progreso por separado para
/// cada uno de esos ejercicios (p.ej. hombro tiene flexión Y abducción,
/// que son movimientos distintos y no deben mezclarse en la misma gráfica
/// aunque compartan la misma articulación).
enum Pathology {
  fracturaHumero,
  capsulitisAdhesiva,
  fracturaCubitoRadio,
  reconstruccionLca,
  lesionMenisco,
  coxartrosisCadera,
  fracturaCaderaOsteosintesis;

  String get label => switch (this) {
    Pathology.fracturaHumero => 'Fractura proximal de húmero (hombro)',
    Pathology.capsulitisAdhesiva => 'Capsulitis adhesiva / hombro congelado',
    Pathology.fracturaCubitoRadio => 'Fractura de cúbito o radio (codo)',
    Pathology.reconstruccionLca => 'Reconstrucción de LCA (rodilla)',
    Pathology.lesionMenisco => 'Lesión de menisco (rodilla)',
    Pathology.coxartrosisCadera => 'Coxartrosis (artrosis de cadera)',
    Pathology.fracturaCaderaOsteosintesis =>
      'Fractura de cadera (cuello femoral) con osteosíntesis',
  };

  /// IDs de `exerciseCatalog` que le corresponden a esta patología — hombro
  /// y coxartrosis necesitan 2 (flexión sagital + abducción frontal, el
  /// documento pide medir ambas por separado); el resto solo 1.
  List<String> get exerciseIds => switch (this) {
    Pathology.fracturaHumero ||
    Pathology.capsulitisAdhesiva => const [
      'hombro_flexion_sagital',
      'hombro_abduccion_frontal',
    ],
    Pathology.fracturaCubitoRadio => const ['codo_flexoextension_sagital'],
    Pathology.reconstruccionLca ||
    Pathology.lesionMenisco => const ['rodilla_flexoextension_sagital'],
    Pathology.coxartrosisCadera => const [
      'cadera_flexion_sagital',
      'cadera_abduccion_frontal',
    ],
    Pathology.fracturaCaderaOsteosintesis => const ['cadera_flexion_sagital'],
  };

  /// IDs de `recommendedExerciseCatalog` — ejercicios terapéuticos (no
  /// medidos con cámara, ver RecommendedExerciseScreen) recomendados según
  /// la fase inicial del protocolo de esta patología (ver
  /// `patologias_objetivo.docx`/`caderas.docx`, sección "Tratamiento").
  List<String> get recommendedExerciseIds => switch (this) {
    Pathology.fracturaHumero => const ['pendulos_codman'],
    Pathology.capsulitisAdhesiva => const ['movilizacion_asistida_hombro'],
    Pathology.fracturaCubitoRadio => const ['movilidad_dedos_muneca'],
    Pathology.reconstruccionLca => const ['extension_activa_rodilla'],
    Pathology.lesionMenisco => const ['flexion_asistida_rodilla'],
    Pathology.coxartrosisCadera => const ['movilidad_articular_cadera'],
    Pathology.fracturaCaderaOsteosintesis => const ['movilizacion_pasiva_cadera'],
  };

  /// Rango de movimiento normal (objetivo clínico) para el ejercicio
  /// [exerciseId], ya en la convención "0° = extendido, sube con la
  /// flexión" en la que `JointAngles.fromPoseFrame` entrega todo ángulo
  /// (ver ese comentario) — no el ángulo crudo del goniómetro. Recibe el
  /// ejercicio porque, a diferencia de hombro (donde
  /// flexión y abducción normales son igual de amplias, 180°), en cadera
  /// difieren: flexión normal 0-120° pero abducción normal solo 0-45°
  /// (ver `caderas.docx`) — un único valor por patología ya no alcanza.
  double targetRomFor(String exerciseId) => switch (this) {
    Pathology.fracturaHumero || Pathology.capsulitisAdhesiva => 180,
    Pathology.fracturaCubitoRadio => 145,
    Pathology.reconstruccionLca || Pathology.lesionMenisco => 145,
    Pathology.coxartrosisCadera =>
      exerciseId == 'cadera_abduccion_frontal' ? 45 : 120,
    Pathology.fracturaCaderaOsteosintesis => 120,
  };
}

/// La patología del catálogo que incluye este ejercicio como medición (ver
/// [Pathology.exerciseIds]), o `null` si no está asignado a ninguna — en
/// ese caso el resumen amigable muestra el dato logrado sin barra de
/// objetivo clínico.
Pathology? pathologyForExercise(String exerciseId) {
  for (final pathology in Pathology.values) {
    if (pathology.exerciseIds.contains(exerciseId)) return pathology;
  }
  return null;
}
