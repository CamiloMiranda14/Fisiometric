import 'dart:ui';

import '../core/pose/pose_landmark_type.dart';

/// Un landmark de pose ya convertido a espacio de píxeles (no normalizado).
///
/// Ver nota en `MediaPipePoseDetectionService`: las coordenadas que entrega
/// el detector vienen normalizadas 0-1 relativas al ancho/alto de la imagen
/// de entrada, y se desnormalizan inmediatamente al construir este objeto
/// para que ningún cálculo de ángulo aguas abajo tenga que preocuparse por
/// el aspect ratio de la imagen original.
class PoseLandmark {
  const PoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.visibility,
  });

  final PoseLandmarkType type;
  final double x;
  final double y;

  /// Confianza [0.0, 1.0]. Ver `kMinLandmarkVisibility` en angle_calculator.dart.
  final double visibility;

  Offset get offset => Offset(x, y);
}
