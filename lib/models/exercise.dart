import '../core/pose/angle_calculator.dart';
import '../core/pose/body_region.dart';
import '../core/pose/body_view.dart';

/// Un ejercicio del catálogo: nombre, video(s) de demostración
/// (empaquetados como asset de la app — los agrega el equipo, no el
/// paciente), la vista de cámara con la que debe medirse, la región del
/// cuerpo que le interesa (para la silueta guía) y qué articulación(es)
/// mide realmente (para no mostrar/exportar ángulos que no le corresponden
/// — ver [trackedJoints]).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.videoAssetPaths,
    required this.view,
    required this.region,
    required this.trackedJoints,
  });

  final String id;
  final String name;

  /// Un video de demostración por lado (`BodyView.izquierda`/`.derecha`) —
  /// el ejercicio frontal de hombro también tiene 2 (uno por brazo que
  /// hace el movimiento), aunque su [view] de cámara sea siempre frontal.
  final Map<BodyView, String> videoAssetPaths;

  final BodyView view;
  final BodyRegion region;

  /// Las articulaciones que este ejercicio realmente mide (ambos lados —
  /// el lado inactivo ya se filtra aparte por vista, ver
  /// `isJointActiveForView`). P.ej. "abducción de hombro" solo trackea
  /// {hombroIzq, hombroDer}, aunque su región (`upperBody`) también
  /// incluya codo/muñeca — esos no se muestran ni se exportan para este
  /// ejercicio en particular.
  final Set<JointKind> trackedJoints;

  /// Video a mostrar según el lado que presenta la patología (ver
  /// `PatientProfile.affectedSide`) — cae al primero disponible si por
  /// algún motivo no hay uno para ese lado exacto.
  String videoAssetPathFor(BodyView side) =>
      videoAssetPaths[side] ?? videoAssetPaths.values.first;

  /// Cuál de [trackedJoints] corresponde al lado [side] (izquierda/derecha)
  /// — usado por ProgressScreen para saber qué columna del CSV/`jointStats`
  /// seguir, en vez de asumir siempre el lado derecho (bug de la primera
  /// versión: un paciente con la patología del lado izquierdo no tenía
  /// datos porque se leía `hombro_der` sin importar cuál era su lado real).
  JointKind? trackedJointFor(BodyView side) {
    final suffix = side == BodyView.izquierda ? 'Izq' : 'Der';
    for (final kind in trackedJoints) {
      if (kind.name.endsWith(suffix)) return kind;
    }
    return null;
  }

  /// Ajusta este ejercicio al lado que el paciente indicó como afectado:
  /// cambia la vista de cámara para los sagitales (codificados como
  /// `derecha` en el catálogo — los frontales no tienen "lado" de cámara
  /// que ajustar, solo de video, ver [videoAssetPathFor]) Y SIEMPRE
  /// restringe [trackedJoints] a solo la articulación del lado afectado.
  ///
  /// La restricción no es solo para los frontales (p.ej. abducción de
  /// hombro, que muestra los DOS lados en el mismo cuadro): en sagital se
  /// asumía que el lado no afectado ni siquiera se detecta, al quedar fuera
  /// de cuadro/oculto por el torso — cierto para hombro/codo/rodilla, pero
  /// no para cadera, donde MediaPipe sigue infiriendo la cadera del otro
  /// lado con confianza aunque la cámara esté de perfil (es un punto ancho
  /// y poco oculto). Sin esta restricción explícita, medir cadera derecha
  /// en sagital igual mostraba/exportaba cadera izquierda.
  Exercise forPatientSide(BodyView affectedSide) {
    final joint = trackedJointFor(affectedSide);
    return Exercise(
      id: id,
      name: name,
      videoAssetPaths: videoAssetPaths,
      view: view == BodyView.frontal ? view : affectedSide,
      region: region,
      trackedJoints: joint == null ? trackedJoints : {joint},
    );
  }
}
