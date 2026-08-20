import '../../core/pose/body_view.dart';
import '../../models/exercise.dart';

/// Lista fija de ejercicios disponibles — sin pantalla en la app para
/// agregar nuevos por ahora. Para agregar un ejercicio real:
/// 1. Copia el archivo .mp4 a `assets/exercises/`.
/// 2. Agrega una entrada aquí con su nombre, la ruta del archivo y la vista
///    (frontal/izquierda/derecha) con la que se debe medir ese ejercicio.
///
/// Los tres de abajo son ejemplos — sus videos (`assets/exercises/*.mp4`)
/// todavía no existen; ExerciseDemoScreen muestra un aviso en vez de
/// reventar si el archivo no está.
const List<Exercise> exerciseCatalog = [
  Exercise(
    id: 'elevacion_hombro_frontal',
    name: 'Elevación de hombro (vista frontal)',
    videoAssetPath: 'assets/exercises/elevacion_hombro_frontal.mp4',
    view: BodyView.frontal,
  ),
  Exercise(
    id: 'flexion_codo_sagital_izquierda',
    name: 'Flexión de codo (vista sagital izquierda)',
    videoAssetPath: 'assets/exercises/flexion_codo_sagital_izquierda.mp4',
    view: BodyView.izquierda,
  ),
  Exercise(
    id: 'flexion_rodilla_sagital_derecha',
    name: 'Flexión de rodilla (vista sagital derecha)',
    videoAssetPath: 'assets/exercises/flexion_rodilla_sagital_derecha.mp4',
    view: BodyView.derecha,
  ),
];
