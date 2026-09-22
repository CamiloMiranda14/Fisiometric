import 'package:flutter/material.dart';

import '../../../core/pose/angle_calculator.dart';
import '../../../core/pose/body_region.dart';
import '../../../core/pose/body_view.dart';
import '../../../core/pose/canvas_projection.dart';
import '../../../core/pose/pose_landmark_type.dart';
import '../../../models/joint_angles.dart';
import '../../../models/pose_frame.dart';
import '../../../theme/app_colors.dart';

/// Landmarks de cara que sí se dibujan — el modelo trae 11 (nariz, 6 puntos
/// de ojos, 2 orejas, 2 de boca), demasiados para lo que aporta un punto de
/// referencia visual; se deja solo un ojo de cada lado (la boca se dibuja
/// aparte, como el punto medio entre sus 2 esquinas — ver paint()).
const Set<PoseLandmarkType> _facialLandmarks = {
  PoseLandmarkType.nose,
  PoseLandmarkType.leftEyeInner,
  PoseLandmarkType.leftEye,
  PoseLandmarkType.leftEyeOuter,
  PoseLandmarkType.rightEyeInner,
  PoseLandmarkType.rightEye,
  PoseLandmarkType.rightEyeOuter,
  PoseLandmarkType.leftEar,
  PoseLandmarkType.rightEar,
  PoseLandmarkType.mouthLeft,
  PoseLandmarkType.mouthRight,
};
const Set<PoseLandmarkType> _visibleFacialLandmarks = {
  PoseLandmarkType.leftEye,
  PoseLandmarkType.rightEye,
};

/// Dibuja el esqueleto (huesos + articulaciones) y las etiquetas de ángulo
/// sobre la vista previa de la cámara.
///
/// IMPORTANTE — supuesto de coordenadas a verificar en un dispositivo real:
/// se asume que `frame.imageWidth`/`imageHeight` y las coordenadas x/y de
/// cada landmark ya están en el espacio de la imagen "derecha" (es decir,
/// que el detector aplicó el parámetro `rotation` — ver
/// MediaPipePoseDetectionService — antes de devolver landmarks, igual que
/// hacen ML Kit y MediaPipe habitualmente). Si al probar en el teléfono el
/// esqueleto aparece rotado o reflejado respecto a la imagen de cámara,
/// este es el primer punto a revisar.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter({
    required this.frame,
    required this.angles,
    required this.view,
    required this.region,
    required this.isFrontFacing,
    this.trackedJoints,
  });

  final PoseFrame frame;
  final JointAngles angles;
  final BodyView view;

  /// Qué parte del cuerpo dibujar — un ejercicio de tren superior no
  /// dibuja rodilla/tobillo, y viceversa (ver BodyRegion).
  final BodyRegion region;

  /// Qué articulación(es) mide el ejercicio actual (ver
  /// `Exercise.trackedJoints`) — cuando son EXCLUSIVAMENTE de cadera, el
  /// esqueleto se restringe más allá del filtro por región: en vez de todo
  /// el tren inferior (incluye tobillo/talón/pie y el lado no afectado, y
  /// hoy además esconde el hombro por error, que sí hace falta para este
  /// ángulo — ver isLandmarkActiveForRegion), se dibuja solo hombro-cadera-
  /// rodilla del lado que el detector esté reportando con confianza (ver
  /// paint()). Para cualquier otro ejercicio (o `null`, p.ej. Prueba
  /// rápida) el filtro sigue siendo por región/vista, sin cambios.
  final Set<JointKind>? trackedJoints;

  /// Confirmado en dispositivo: la vista previa de la cámara frontal viene
  /// espejada por hardware (comportamiento normal de "selfie"), pero el
  /// flujo de análisis que usa el detector de pose NO — los datos/ángulos
  /// ya están bien calculados sobre ese flujo sin espejar, así que aquí
  /// solo se voltea el DIBUJO para que coincida con la vista previa
  /// espejada, sin tocar landmarks/ángulos.
  final bool isFrontFacing;

  static final Paint _bonePaint = Paint()
    ..color = AppColors.orangeAccent
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;

  static final Paint _jointFillPaint = Paint()..color = Colors.white;

  static final Paint _jointBorderPaint = Paint()
    ..color = AppColors.tealPrimary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  static const TextStyle _labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.bold,
    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (!frame.hasPose || frame.imageWidth == 0 || frame.imageHeight == 0) {
      return;
    }

    Offset toCanvas(double x, double y) => imageToCanvas(
      x: x,
      y: y,
      imageWidth: frame.imageWidth,
      imageHeight: frame.imageHeight,
      canvasSize: size,
      isFrontFacing: isFrontFacing,
    );

    // Cuando el ejercicio mide SOLO cadera, se restringe a hombro-cadera-
    // rodilla del lado que el detector esté reportando con confianza en
    // este cuadro — ni el resto del tren inferior (tobillo/talón/pie) ni
    // el lado no afectado. `null` mientras no haya un lado con confianza
    // todavía (no se dibuja nada de esto ese cuadro).
    final joints = trackedJoints;
    final isCaderaOnly =
        joints != null &&
        joints.isNotEmpty &&
        joints.every((k) => k == JointKind.caderaIzq || k == JointKind.caderaDer);
    Set<PoseLandmarkType>? caderaAllowed;
    if (isCaderaOnly) {
      final sideKind = angles.forJoint(JointKind.caderaDer) != null
          ? JointKind.caderaDer
          : (angles.forJoint(JointKind.caderaIzq) != null ? JointKind.caderaIzq : null);
      if (sideKind != null) {
        final def = jointDefinitions.firstWhere((d) => d.kind == sideKind);
        caderaAllowed = {def.a, def.vertex, def.c};
      }
    }

    bool isActive(PoseLandmarkType type) {
      if (isCaderaOnly) return caderaAllowed?.contains(type) ?? false;
      return isLandmarkActiveForView(type, view) && isLandmarkActiveForRegion(type, region);
    }

    for (final (fromType, toType) in skeletonBones) {
      if (!isActive(fromType) || !isActive(toType)) continue;
      final from = frame[fromType];
      final to = frame[toType];
      if (from == null || to == null) continue;
      if (from.visibility < kMinLandmarkVisibility ||
          to.visibility < kMinLandmarkVisibility) {
        continue;
      }
      canvas.drawLine(
        toCanvas(from.x, from.y),
        toCanvas(to.x, to.y),
        _bonePaint,
      );
    }

    for (final landmark in frame.landmarks.values) {
      if (_facialLandmarks.contains(landmark.type) &&
          !_visibleFacialLandmarks.contains(landmark.type)) {
        continue;
      }
      if (!isActive(landmark.type)) continue;
      if (landmark.visibility < kMinLandmarkVisibility) continue;
      final center = toCanvas(landmark.x, landmark.y);
      canvas.drawCircle(center, 5, _jointFillPaint);
      canvas.drawCircle(center, 5, _jointBorderPaint);
    }

    // La boca se reduce a un solo punto (el medio entre sus 2 esquinas) en
    // vez de sus 2 landmarks crudos — ver _facialLandmarks arriba.
    final mouthLeft = frame[PoseLandmarkType.mouthLeft];
    final mouthRight = frame[PoseLandmarkType.mouthRight];
    if (!isCaderaOnly &&
        mouthLeft != null &&
        mouthRight != null &&
        mouthLeft.visibility >= kMinLandmarkVisibility &&
        mouthRight.visibility >= kMinLandmarkVisibility) {
      final mouthCenter = toCanvas(
        (mouthLeft.x + mouthRight.x) / 2,
        (mouthLeft.y + mouthRight.y) / 2,
      );
      canvas.drawCircle(mouthCenter, 5, _jointFillPaint);
      canvas.drawCircle(mouthCenter, 5, _jointBorderPaint);
    }

    for (final def in jointDefinitions) {
      final value = angles.forJoint(def.kind);
      if (value == null) continue;
      final vertex = frame[def.vertex];
      if (vertex == null) continue;

      final textPainter = TextPainter(
        text: TextSpan(text: '${value.round()}°', style: _labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, toCanvas(vertex.x, vertex.y) + const Offset(8, -8));
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.angles != angles ||
        oldDelegate.view != view ||
        oldDelegate.region != region;
  }
}
