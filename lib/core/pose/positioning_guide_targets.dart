import 'dart:ui';

import 'body_outline_images.dart';
import 'body_region.dart';
import 'body_view.dart';
import 'pose_landmark_type.dart';

/// Centro de la cabeza en la silueta guía (fracción 0-1 del lienzo) — igual
/// en las 3 vistas, ya que siempre queda centrada horizontalmente.
const Offset positioningHeadFraction = Offset(0.5, 0.12);

/// Radio de la cabeza en la silueta guía, como fracción del alto del
/// lienzo.
const double positioningHeadRadiusFraction = 0.05;

/// Escala de la silueta guía en tren superior, respecto al tamaño que
/// ocuparía si llenara el lienzo entero (1.0) — más chica a propósito: deja
/// margen alrededor para que, si el paciente levanta o extiende el brazo
/// durante el ejercicio, el brazo real (visible por cámara) tenga espacio
/// de sobra para seguir dentro de cuadro, en vez de salirse justo donde
/// termina la silueta. `PositioningGuidePainter` DEBE escalar `dstSize` por
/// esta misma constante antes de centrar/desplazar — es la única forma de
/// que la silueta dibujada y esta función de objetivos no queden
/// desfasadas entre sí (ya pasó una vez al mover el centrado sin replicarlo
/// acá).
const double kUpperBodyGuideScale = 0.8;

/// Posiciones objetivo (fracciones 0-1 del lienzo) de la silueta guía por
/// vista y región — única fuente usada tanto para dibujarla
/// (PositioningGuidePainter, reusando `skeletonBones` para saber qué huesos
/// trazar) como para revisar si el paciente ya se alineó con ella
/// (positioning_alignment.dart).
///
/// Cubre los mismos landmarks que aparecen en `skeletonBones` para poder
/// reusar esa lista de huesos tal cual, sin duplicar qué puntos se conectan.
///
/// Para `region == upperBody`, `PositioningGuidePainter` no solo centra la
/// franja cabeza-cintura en el lienzo sino que además la encoge a
/// [kUpperBodyGuideScale] antes de centrarla — la transformación combinada
/// (escalar alrededor del centro del lienzo, más el corrimiento vertical
/// para centrar esa franja) da, para una fracción cruda `f` de la imagen
/// completa sin escalar:
///   x' = 0.5 + s·(x - 0.5)
///   y' = 0.5 + s·(y - W/2)
/// con `s = kUpperBodyGuideScale` y `W = kOutlineWaistFraction` — se deduce
/// asumiendo que la silueta a escala 1 ocupa prácticamente todo el lienzo
/// (mismo supuesto que ya hacían estas fracciones antes de tener en cuenta
/// la región), igual que hace el painter.
Map<PoseLandmarkType, Offset> positioningGuideTargets(BodyView view, BodyRegion region) {
  final raw = _rawPositioningGuideTargets(view);
  if (region != BodyRegion.upperBody) return raw;
  const s = kUpperBodyGuideScale;
  return raw.map(
    (type, offset) => MapEntry(
      type,
      Offset(
        0.5 + s * (offset.dx - 0.5),
        0.5 + s * (offset.dy - kOutlineWaistFraction / 2),
      ),
    ),
  );
}

Map<PoseLandmarkType, Offset> _rawPositioningGuideTargets(BodyView view) {
  if (view == BodyView.frontal) {
    return const {
      PoseLandmarkType.leftShoulder: Offset(0.38, 0.24),
      PoseLandmarkType.rightShoulder: Offset(0.62, 0.24),
      PoseLandmarkType.leftElbow: Offset(0.30, 0.40),
      PoseLandmarkType.rightElbow: Offset(0.70, 0.40),
      PoseLandmarkType.leftWrist: Offset(0.26, 0.54),
      PoseLandmarkType.rightWrist: Offset(0.74, 0.54),
      PoseLandmarkType.leftIndex: Offset(0.24, 0.58),
      PoseLandmarkType.rightIndex: Offset(0.76, 0.58),
      PoseLandmarkType.leftHip: Offset(0.42, 0.56),
      PoseLandmarkType.rightHip: Offset(0.58, 0.56),
      PoseLandmarkType.leftKnee: Offset(0.40, 0.76),
      PoseLandmarkType.rightKnee: Offset(0.56, 0.76),
      PoseLandmarkType.leftAnkle: Offset(0.40, 0.95),
      PoseLandmarkType.rightAnkle: Offset(0.56, 0.95),
    };
  }

  // Perfil lateral: una sola cadena de landmarks, del lado que
  // efectivamente mide esa vista (mismo criterio que isJointActiveForView)
  // — viendo hacia la derecha por convención, espejado para "derecha".
  final flip = view == BodyView.derecha;
  double fx(double dx) => flip ? 1 - dx : dx;
  final isIzq = view == BodyView.izquierda;

  final shoulder = isIzq ? PoseLandmarkType.leftShoulder : PoseLandmarkType.rightShoulder;
  final elbow = isIzq ? PoseLandmarkType.leftElbow : PoseLandmarkType.rightElbow;
  final wrist = isIzq ? PoseLandmarkType.leftWrist : PoseLandmarkType.rightWrist;
  final index = isIzq ? PoseLandmarkType.leftIndex : PoseLandmarkType.rightIndex;
  final hip = isIzq ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip;
  final knee = isIzq ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee;
  final ankle = isIzq ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle;

  // El brazo se mantiene pegado al torso (codo/muñeca casi en línea con el
  // hombro y la cadera) en vez de separado hacia adelante — en vista
  // sagital el brazo relajado cuelga junto al cuerpo, no extendido.
  return {
    shoulder: Offset(fx(0.5), 0.24),
    elbow: Offset(fx(0.53), 0.38),
    wrist: Offset(fx(0.52), 0.52),
    index: Offset(fx(0.51), 0.55),
    hip: Offset(fx(0.47), 0.56),
    knee: Offset(fx(0.51), 0.76),
    ankle: Offset(fx(0.46), 0.95),
  };
}

/// Landmarks "ancla" para revisar alineación con la silueta guía — solo
/// hombros y caderas: son los puntos más estables para confirmar distancia
/// y encuadre frente a la cámara. Muñecas/codos/rodillas/tobillos se
/// mueven naturalmente incluso estando bien parado, así que exigir que
/// también coincidan haría casi imposible "aprobar" la alineación.
List<PoseLandmarkType> positioningAnchors(BodyView view) {
  if (view == BodyView.frontal) {
    return const [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];
  }
  final isIzq = view == BodyView.izquierda;
  return [
    isIzq ? PoseLandmarkType.leftShoulder : PoseLandmarkType.rightShoulder,
    isIzq ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip,
  ];
}
