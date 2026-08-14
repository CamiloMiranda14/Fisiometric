import '../core/pose/pose_landmark_type.dart';
import 'pose_landmark.dart';

/// Todos los landmarks detectados en un frame de cámara, ya en espacio de
/// píxeles. Un [PoseFrame] sin landmarks (`hasPose == false`) representa
/// "no se detectó ninguna persona en este frame", no un error.
class PoseFrame {
  const PoseFrame({
    required this.landmarks,
    required this.imageWidth,
    required this.imageHeight,
  });

  static const empty = PoseFrame(
    landmarks: <PoseLandmarkType, PoseLandmark>{},
    imageWidth: 0,
    imageHeight: 0,
  );

  final Map<PoseLandmarkType, PoseLandmark> landmarks;
  final int imageWidth;
  final int imageHeight;

  bool get hasPose => landmarks.isNotEmpty;

  PoseLandmark? operator [](PoseLandmarkType type) => landmarks[type];
}
