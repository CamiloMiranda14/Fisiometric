import 'package:flutter/material.dart';

import '../../../core/pose/angle_calculator.dart';
import '../../../models/joint_angles.dart';
import '../../../models/pose_frame.dart';
import '../../../theme/app_colors.dart';

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
  SkeletonPainter({required this.frame, required this.angles});

  final PoseFrame frame;
  final JointAngles angles;

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

    final scaleX = size.width / frame.imageWidth;
    final scaleY = size.height / frame.imageHeight;
    Offset toCanvas(double x, double y) => Offset(x * scaleX, y * scaleY);

    for (final (fromType, toType) in skeletonBones) {
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
      if (landmark.visibility < kMinLandmarkVisibility) continue;
      final center = toCanvas(landmark.x, landmark.y);
      canvas.drawCircle(center, 5, _jointFillPaint);
      canvas.drawCircle(center, 5, _jointBorderPaint);
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
    return oldDelegate.frame != frame || oldDelegate.angles != angles;
  }
}
