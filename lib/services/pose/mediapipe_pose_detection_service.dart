import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter_pose_detection/flutter_pose_detection.dart' as mp;

import '../../core/errors/app_exceptions.dart';
import '../../core/pose/camera_rotation.dart';
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
  String? _lastError;

  @override
  String? get lastError => _lastError;

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
    required bool isFrontFacing,
  }) async {
    if (!_initialized) return null;

    final rotation = cameraFrameRotation(
      sensorOrientation: sensorOrientation,
      isFrontFacing: isFrontFacing,
    );

    final formatGroup = image.format.group;
    final List<Map<String, dynamic>> planes;
    if (formatGroup == cam.ImageFormatGroup.yuv420 ||
        formatGroup == cam.ImageFormatGroup.nv21) {
      // La conversión nativa YUV→bitmap de este paquete asume ingenuamente
      // que cada plano mide exactamente `width * height` bytes sin relleno
      // de fila ni bytes intercalados entre muestras de croma — no usa
      // `bytesPerRow`/`bytesPerPixel` para nada. En dispositivos donde el
      // HAL de la cámara sí rellena filas o intercala croma (confirmado en
      // la cámara frontal de un Moto G47: "IndexOutOfBoundsException:
      // length=518400; index=518400"), pasar el buffer crudo hace que esa
      // conversión lea/escriba un byte más allá del buffer y falle. Se
      // "reempaqueta" cada plano aquí para que siempre llegue sin relleno,
      // sin depender de que el paquete corrija su propio bug nativo.
      //
      // Solo aplica a formatos planares 1-byte-por-muestra (YUV): en
      // bgra8888 (rama de abajo) cada píxel ya mide 4 bytes y "empaquetar"
      // con esta misma lógica se comería 3 de cada 4 bytes de color.
      planes = [
        for (var i = 0; i < image.planes.length; i++)
          _packedPlaneMap(image, i),
      ];
    } else {
      // Mismo formato que el ejemplo oficial del paquete: bytesPerPixel se
      // deja tal cual (es null en iOS) en vez de inventar un valor por
      // defecto que el lado nativo no está esperando.
      planes = image.planes
          .map(
            (p) => {
              'bytes': p.bytes,
              'bytesPerRow': p.bytesPerRow,
              'bytesPerPixel': p.bytesPerPixel,
            },
          )
          .toList();
    }

    final mp.PoseResult result;
    try {
      result = await _detector.processFrame(
        planes: planes,
        width: image.width,
        height: image.height,
        format: _formatGroupName(image.format.group),
        rotation: rotation,
      );
    } on mp.DetectionError catch (e) {
      // Un frame individual puede fallar (p.ej. buffer inconsistente); se
      // descarta y se sigue con el siguiente — este paquete es joven y no
      // debe poder tumbar el pipeline en vivo por un solo frame malo.
      //
      // `e.toString()` solo trae code+message genéricos ("Frame processing
      // failed"); el motivo real que reporta el lado nativo (Kotlin/Swift)
      // viaja en `platformMessage` — hay que incluirlo o queda invisible.
      _lastError = '$e | platform: ${e.platformMessage}';
      debugPrint('[Fisiometric] Frame de pose descartado: $_lastError');
      return null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[Fisiometric] Frame de pose descartado: $e');
      return null;
    }
    _lastError = null;
    return _poseFrameFromResult(result);
  }

  /// Convierte el resultado crudo del detector a nuestro propio [PoseFrame].
  ///
  /// Confirmado en dispositivo (captura de pantalla, brazo izquierdo
  /// levantado): MediaPipe etiqueta izquierda/derecha correctamente sin
  /// ningún ajuste — no mirrorizar aquí (ver SkeletonPainter para el único
  /// ajuste de espejo que sí hace falta, y que es puramente visual,
  /// exclusivo de la cámara frontal en vivo).
  PoseFrame _poseFrameFromResult(mp.PoseResult result) {
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

  /// Arma el mapa de un plano ya empaquetado (ver [processCameraImage])
  /// para el plano [index] de [image].
  Map<String, dynamic> _packedPlaneMap(cam.CameraImage image, int index) {
    final plane = image.planes[index];
    final pixelStride = plane.bytesPerPixel ?? 1;
    // Y (plano 0) mide el frame completo; U/V (4:2:0) miden la mitad de
    // ancho y alto — igual que asume el bucle de interleaving nativo.
    final planeWidth = index == 0 ? image.width : (image.width / 2).ceil();
    final planeHeight = index == 0 ? image.height : (image.height / 2).ceil();
    final packedBytes = _packPlane(
      bytes: plane.bytes,
      bytesPerRow: plane.bytesPerRow,
      pixelStride: pixelStride,
      width: planeWidth,
      height: planeHeight,
    );
    return {'bytes': packedBytes, 'bytesPerRow': planeWidth, 'bytesPerPixel': 1};
  }

  /// Copia [bytes] a un buffer sin relleno de fila (cuando [bytesPerRow] >
  /// `width * pixelStride`) ni bytes intercalados entre muestras (cuando
  /// [pixelStride] > 1) — ver comentario en [processCameraImage].
  Uint8List _packPlane({
    required Uint8List bytes,
    required int bytesPerRow,
    required int pixelStride,
    required int width,
    required int height,
  }) {
    if (bytesPerRow == width && pixelStride == 1) {
      // Ya viene empaquetado — evita la copia en el caso común (la mayoría
      // de dispositivos no rellenan filas).
      return bytes;
    }
    final out = Uint8List(width * height);
    if (pixelStride == 1) {
      // Solo hay relleno de fila (sin bytes intercalados entre muestras):
      // copiar cada fila completa de una vez (operación nativa en bloque)
      // es muchísimo más rápido que ir byte a byte — importa porque esto
      // corre en cada frame de un stream en vivo.
      for (var row = 0; row < height; row++) {
        final rowStart = row * bytesPerRow;
        out.setRange(row * width, row * width + width, bytes, rowStart);
      }
      return out;
    }
    // Además hay bytes intercalados entre muestras (típico en croma U/V) —
    // ahí sí hace falta ir byte a byte.
    var outIndex = 0;
    for (var row = 0; row < height; row++) {
      final rowStart = row * bytesPerRow;
      for (var col = 0; col < width; col++) {
        out[outIndex++] = bytes[rowStart + col * pixelStride];
      }
    }
    return out;
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
