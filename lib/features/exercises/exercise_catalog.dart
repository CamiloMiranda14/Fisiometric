import '../../core/pose/angle_calculator.dart';
import '../../core/pose/body_region.dart';
import '../../core/pose/body_view.dart';
import '../../models/exercise.dart';

/// Catálogo "de fábrica" — moldeado a las 5 patologías objetivo del sistema
/// (ver `patologias_objetivo.docx`), agrupadas en 4 ejercicios (hombro
/// tiene 2 movimientos porque el documento pide medir flexión Y abducción
/// por separado; codo y rodilla solo un movimiento cada uno), más la
/// medición de cadera agregada después, sin patología propia todavía. Las
/// mismas 2 patologías de hombro (fractura de húmero, capsulitis adhesiva)
/// y las 2 de rodilla (LCA, menisco) comparten exactamente la misma toma
/// (mismo ángulo, misma vista), así que no hace falta un ejercicio por
/// patología, sino uno por movimiento medido:
///
/// - Hombro — fractura de húmero / capsulitis adhesiva:
///   flexión anterior (sagital, ángulo codo-hombro-cadera) y abducción
///   lateral (frontal, mismo ángulo).
/// - Codo — fractura de cúbito/radio: flexoextensión (sagital, ángulo
///   hombro-codo-muñeca).
/// - Cadera — sin patología asignada aún: flexión (sagital, ángulo
///   hombro-cadera-rodilla).
/// - Rodilla — reconstrucción de LCA / lesión de menisco: flexoextensión
///   (sagital, ángulo cadera-rodilla-tobillo).
///
/// Cada uno tiene un video de demostración por lado — ver
/// `PatientProfile.affectedSide`, con el que HomeScreen/ExerciseCatalogScreen
/// eligen cuál mostrar y ajustan la vista de cámara de los sagitales.
const List<Exercise> exerciseCatalog = [
  Exercise(
    id: 'hombro_flexion_sagital',
    name: 'Flexión de hombro (plano sagital)',
    videoAssetPaths: {
      BodyView.izquierda: 'assets/exercises/hombro_flexion_sagital_izquierdo.mp4',
      BodyView.derecha: 'assets/exercises/hombro_flexion_sagital_derecho.mp4',
    },
    view: BodyView.derecha,
    region: BodyRegion.upperBody,
    trackedJoints: {JointKind.hombroIzq, JointKind.hombroDer},
  ),
  Exercise(
    id: 'hombro_abduccion_frontal',
    name: 'Abducción de hombro (plano frontal)',
    videoAssetPaths: {
      BodyView.izquierda: 'assets/exercises/hombro_abduccion_frontal_izquierdo.mp4',
      BodyView.derecha: 'assets/exercises/hombro_abduccion_frontal_derecho.mp4',
    },
    view: BodyView.frontal,
    region: BodyRegion.upperBody,
    trackedJoints: {JointKind.hombroIzq, JointKind.hombroDer},
  ),
  Exercise(
    id: 'codo_flexoextension_sagital',
    name: 'Flexoextensión de codo (plano sagital)',
    videoAssetPaths: {
      BodyView.izquierda: 'assets/exercises/codo_flexoextension_sagital_izquierdo.mp4',
      BodyView.derecha: 'assets/exercises/codo_flexoextension_sagital_derecho.mp4',
    },
    view: BodyView.derecha,
    region: BodyRegion.upperBody,
    trackedJoints: {JointKind.codoIzq, JointKind.codoDer},
  ),
  Exercise(
    id: 'cadera_flexion_sagital',
    name: 'Flexión de cadera (plano sagital)',
    videoAssetPaths: {
      BodyView.izquierda: 'assets/exercises/cadera_flexion_sagital_izquierdo.mp4',
      BodyView.derecha: 'assets/exercises/cadera_flexion_sagital_derecho.mp4',
    },
    view: BodyView.derecha,
    region: BodyRegion.lowerBody,
    trackedJoints: {JointKind.caderaIzq, JointKind.caderaDer},
  ),
  Exercise(
    id: 'cadera_abduccion_frontal',
    name: 'Abducción de cadera (plano frontal)',
    videoAssetPaths: {
      BodyView.izquierda: 'assets/exercises/cadera_abduccion_frontal_izquierdo.mp4',
      BodyView.derecha: 'assets/exercises/cadera_abduccion_frontal_derecho.mp4',
    },
    view: BodyView.frontal,
    region: BodyRegion.lowerBody,
    trackedJoints: {JointKind.caderaIzq, JointKind.caderaDer},
  ),
  Exercise(
    id: 'rodilla_flexoextension_sagital',
    name: 'Flexoextensión de rodilla (plano sagital)',
    videoAssetPaths: {
      BodyView.izquierda: 'assets/exercises/rodilla_flexoextension_sagital_izquierdo.mp4',
      BodyView.derecha: 'assets/exercises/rodilla_flexoextension_sagital_derecho.mp4',
    },
    view: BodyView.derecha,
    region: BodyRegion.lowerBody,
    trackedJoints: {JointKind.rodillaIzq, JointKind.rodillaDer},
  ),
];

/// Qué articulaciones mide el ejercicio [exerciseId] — `null` si no hay tal
/// ejercicio (p.ej. "Prueba rápida", que no restringe nada; ver
/// isJointActiveForRegion, que sigue aplicando igual). Se usa para volver a
/// derivar el filtro tanto en vivo (MeasureScreen) como al releer una
/// sesión ya guardada (SessionDetailScreen/SessionResultScreen/
/// MovementChart), a partir del `exerciseId` guardado en esa sesión.
Set<JointKind>? trackedJointsForExerciseId(String? exerciseId) {
  if (exerciseId == null) return null;
  return exerciseForId(exerciseId)?.trackedJoints;
}

/// El `Exercise` del catálogo con este [id], o `null` si no existe — ver
/// [trackedJointsForExerciseId] para el caso de uso más común (releer una
/// sesión guardada a partir de su `exerciseId`).
Exercise? exerciseForId(String? exerciseId) {
  if (exerciseId == null) return null;
  for (final exercise in exerciseCatalog) {
    if (exercise.id == exerciseId) return exercise;
  }
  return null;
}
