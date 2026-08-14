import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter_pose_detection/flutter_pose_detection.dart' as mp;

import '../../core/errors/app_exceptions.dart';
import '../../core/pose/pose_landmark_type.dart';
import '../../models/pose_frame.dart';
import '../../models/pose_landmark.dart';
import 'pose_detection_service.dart';

/// Único archivo del proyecto que importa `flutter_pose_detection`.
///
/// Envuelve `NpuPoseDetector` (MediaPipe PoseLandmarker por debajo: Android
/// usa MediaPipe Tasks Vision con delegado GPU, iOS usa TFLite + CoreML) y
/// traduce su salida a los modelos propios de la app.
class MediaPipePoseDetectionService implements PoseDetectionService {
  final mp.NpuPoseDetector _detector = mp.NpuPoseDetector(
    config: mp.PoseDetectorConfig.realtime(),
  );
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    try {
      final mode = await _detector.initialize();
      _initialized = true;
      debugPrint('[Fisiometric] Detector de pose listo — aceleración: $mode');
    } on mp.DetectionError catch (e) {
      throw PoseDetectorInitException(
        '${e.message}${e.recoverySuggestion != null ? ' (${e.recoverySuggestion})' : ''}',
      );
    } catch (e) {
      throw PoseDetectorInitException(
        'No se pudo inicializar el detector de pose: $e',
      );
    }
  }

  @override
  Future<PoseFrame?> processCameraImage(
    cam.CameraImage image, {
    required int sensorOrientation,
  }) async {
    if (!_initialized) return null;

    // Mismo formato que el ejemplo oficial del paquete: bytesPerPixel se
    // deja tal cual (es null en iOS) en vez de inventar un valor por
    // defecto que el lado nativo no está esperando.
    final planes = image.planes
        .map(
          (p) => {
            'bytes': p.bytes,
            'bytesPerRow': p.bytesPerRow,
            'bytesPerPixel': p.bytesPerPixel,
          },
        )
        .toList();

    final mp.PoseResult result;
    try {
      result = await _detector.processFrame(
        planes: planes,
        width: image.width,
        height: image.height,
        format: _formatGroupName(image.format.group),
        rotation: sensorOrientation,
      );
    } catch (e) {
      // Un frame individual puede fallar (p.ej. buffer inconsistente); se
      // descarta y se sigue con el siguiente — este paquete es joven y no
      // debe poder tumbar el pipeline en vivo por un solo frame malo.
      debugPrint('[Fisiometric] Frame de pose descartado: $e');
      return null;
    }

    final pose = result.firstPose;
    if (pose == null) return PoseFrame.empty;

    final landmarks = <PoseLandmarkType, PoseLandmark>{};
    for (final rawType in mp.LandmarkType.values) {
      final ourType = PoseLandmarkType.values[rawType.value];
      final raw = pose.getLandmark(rawType);
      final pixel = raw.toPixelCoordinates(result.imageWidth, result.imageHeight);
      landmarks[ourType] = PoseLandmark(
        type: ourType,
        x: pixel.dx,
        y: pixel.dy,
        visibility: raw.visibility,
      );
    }

    return PoseFrame(
      landmarks: landmarks,
      imageWidth: result.imageWidth,
      imageHeight: result.imageHeight,
    );
  }

  @override
  Future<void> dispose() async {
    _detector.dispose();
    _initialized = false;
  }

  /// `image.format.group` solo tiene el string `.name()` disponible vía una
  /// extensión de `camera_platform_interface` que `package:camera` no
  /// reexporta — se mapea a mano para no depender de un import transitivo.
  String _formatGroupName(cam.ImageFormatGroup group) {
    switch (group) {
      case cam.ImageFormatGroup.yuv420:
        return 'yuv420';
      case cam.ImageFormatGroup.bgra8888:
        return 'bgra8888';
      case cam.ImageFormatGroup.nv21:
        return 'nv21';
      case cam.ImageFormatGroup.jpeg:
      case cam.ImageFormatGroup.unknown:
        return 'yuv420';
    }
  }
}
