import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Modo de grabación "limpio": una sola llamada nativa
/// (`startVideoRecording(onAvailable:)`) produce el video Y sigue
/// alimentando la detección de pose en vivo al mismo tiempo — nunca se
/// mezcla con `startImageStream` de forma independiente (ver
/// flutter/flutter#150005: hacerlo corrompe el stream).
///
/// Como la vista de medición ya corre `startImageStream` de forma continua
/// para el HUD en vivo, hay que detenerlo primero y reanudarlo después.
class CleanVideoRecorder {
  const CleanVideoRecorder();

  /// Detiene el streaming plano (si estaba activo) y arranca la grabación
  /// nativa con streaming combinado.
  ///
  /// En algunos dispositivos, `startVideoRecording(onAvailable:)` puede
  /// fallar por no soportar esa combinación de superficies de captura (ver
  /// flutter/flutter#134814, error de cámara "Function not implemented").
  /// Ante cualquier fallo de la variante combinada, se reintenta sin
  /// streaming: el video se graba igual, pero esa toma queda sin ángulos
  /// sincronizados. Devuelve `true` si el streaming en vivo sigue activo
  /// durante la grabación, `false` si se usó ese resguardo.
  Future<bool> start(
    CameraController controller,
    void Function(CameraImage image) onFrame,
  ) async {
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }

    try {
      await controller.startVideoRecording(onAvailable: onFrame);
      return true;
    } on CameraException catch (e) {
      debugPrint(
        '[Fisiometric] startVideoRecording(onAvailable:) falló ($e); '
        'grabando sin ángulos en vivo para esta toma.',
      );
      await controller.startVideoRecording();
      return false;
    }
  }

  /// Detiene la grabación, copia el archivo a [destinationPath] y reanuda
  /// el streaming plano para que el HUD siga funcionando fuera de grabación.
  Future<void> stop(
    CameraController controller,
    String destinationPath,
    void Function(CameraImage image) onFrame,
  ) async {
    final file = await controller.stopVideoRecording();
    await file.saveTo(destinationPath);
    await controller.startImageStream(onFrame);
  }
}
