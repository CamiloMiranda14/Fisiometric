import 'dart:ui';

import '../../models/pose_frame.dart';
import 'angle_calculator.dart';
import 'body_region.dart';
import 'body_view.dart';
import 'canvas_projection.dart';
import 'positioning_guide_targets.dart';

/// Distancia máxima (fracción del alto del lienzo) entre un landmark ancla
/// real y su objetivo en la silueta guía para considerarlo "alineado".
/// 0.12 es deliberadamente permisivo — el objetivo es confirmar que el
/// paciente está parado a una distancia/posición razonable, no exigir una
/// pose milimétrica que nadie puede sostener quieta.
const double kAlignmentToleranceFraction = 0.12;

/// Si el frame detectado está lo bastante alineado con la silueta guía de
/// [view] como para empezar la cuenta regresiva de grabación — ver
/// MeasureScreen. Compara solo los landmarks "ancla" (positioningAnchors);
/// si cualquiera falta, tiene confianza baja, o queda fuera de tolerancia,
/// se considera no alineado.
bool isAlignedWithGuide({
  required PoseFrame frame,
  required BodyView view,
  required BodyRegion region,
  required Size canvasSize,
  required bool isFrontFacing,
}) {
  if (canvasSize.isEmpty || frame.imageWidth == 0 || frame.imageHeight == 0) {
    return false;
  }

  final targets = positioningGuideTargets(view, region);
  final tolerance = kAlignmentToleranceFraction * canvasSize.height;

  for (final type in positioningAnchors(view)) {
    final landmark = frame[type];
    if (landmark == null || landmark.visibility < kMinLandmarkVisibility) {
      return false;
    }

    final targetFraction = targets[type];
    if (targetFraction == null) return false;

    final real = imageToCanvas(
      x: landmark.x,
      y: landmark.y,
      imageWidth: frame.imageWidth,
      imageHeight: frame.imageHeight,
      canvasSize: canvasSize,
      isFrontFacing: isFrontFacing,
    );
    final target = Offset(
      targetFraction.dx * canvasSize.width,
      targetFraction.dy * canvasSize.height,
    );
    if ((real - target).distance > tolerance) return false;
  }
  return true;
}
