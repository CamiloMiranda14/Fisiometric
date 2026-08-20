import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../core/errors/app_exceptions.dart';

/// Resolución usada para el stream de cámara.
///
/// Gobierna a la vez la calidad del video nativo (modo de grabación limpio,
/// ver CleanVideoRecorder) y el tamaño de cada frame que se envía al
/// detector de pose — cada frame se codifica en base64 antes de cruzar el
/// method channel, así que un preset muy alto puede saturar ese canal en
/// dispositivos de gama baja. Bajado de `medium` a `low`: confirmado en
/// dispositivo (Moto G47) que con `medium` el análisis por cuadro tarda
/// más que el tiempo real entre cuadros, así que el esqueleto dibujado
/// siempre queda mostrando un instante anterior — visible como que "no
/// alcanza" al brazo mientras se mueve, aunque el ángulo calculado en sí
/// sea correcto.
const kCameraResolutionPreset = ResolutionPreset.low;

/// Maneja el ciclo de vida de un [CameraController] único, compartido tanto
/// por la vista previa/detección de pose como por los dos modos de grabación.
class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Inicializa la cámara trasera (o la primera disponible) sin audio, en
  /// formato YUV420 (compatible con el detector de pose en ambas
  /// plataformas) y con la orientación de captura bloqueada a portrait.
  ///
  /// Lanza [CameraUnavailableException] si no hay cámara o si falla el init.
  Future<CameraController> initialize({
    CameraLensDirection preferredLens = CameraLensDirection.back,
  }) async {
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      throw CameraUnavailableException(
        e.description ?? 'No se pudo listar las cámaras del dispositivo (${e.code}).',
      );
    }

    if (cameras.isEmpty) {
      throw const CameraUnavailableException(
        'No se detectó ninguna cámara en este dispositivo.',
      );
    }

    final description = cameras.firstWhere(
      (c) => c.lensDirection == preferredLens,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      description,
      kCameraResolutionPreset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on CameraException catch (e) {
      await controller.dispose();
      throw CameraUnavailableException(
        e.description ?? 'No se pudo iniciar la cámara (${e.code}).',
      );
    }

    _controller = controller;
    return controller;
  }

  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
