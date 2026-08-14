import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';

/// Modo de grabación "overlay quemado".
///
/// No usa grabación nativa en absoluto: el streaming de cámara para pose
/// sigue corriendo por su cuenta (ver MeasureScreen — nunca se detiene para
/// este modo), y este recorder solo captura lo que ya se está pintando en
/// pantalla (cámara + esqueleto, vía un `RepaintBoundary` propio) y lo
/// codifica cuadro a cuadro como un mp4 independiente.
///
/// Es, a propósito, más lento y de menor fidelidad que el modo limpio — la
/// composición ocurre en Dart, no en el codec nativo de la cámara — y el
/// pipeline más delicado de la app: si el capturado no llega al ritmo
/// configurado en `_fps`, el video resultante queda "acelerado" respecto al
/// tiempo real (cada cuadro se marca como 1/fps segundos sin importar
/// cuánto tardó realmente en capturarse). Ver angle_sample.timestampMs para
/// la sincronización real con los datos, que no depende de esto.
class OverlayVideoRecorder {
  static const int _fps = 20;
  static const int _audioSampleRate = 16000;
  static const Duration _captureInterval = Duration(milliseconds: 1000 ~/ _fps);

  Timer? _timer;
  bool _busyCapturing = false;
  int _width = 0;
  int _height = 0;

  /// Silencio a anexar junto a cada video frame: el encoder exige una pista
  /// de audio configurada aunque este modo no usa el micrófono en ningún
  /// momento (no se solicita RECORD_AUDIO).
  Uint8List _silentAudioFrame = Uint8List(0);

  bool get isRecording => _timer != null;

  Future<void> start({
    required GlobalKey repaintBoundaryKey,
    required String outputPath,
  }) async {
    final renderObject = repaintBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('El RepaintBoundary del overlay no está montado.');
    }

    _width = renderObject.size.width.round();
    _height = renderObject.size.height.round();

    await FlutterQuickVideoEncoder.setup(
      width: _width,
      height: _height,
      fps: _fps,
      videoBitrate: 4 * 1000 * 1000,
      profileLevel: ProfileLevel.any,
      audioChannels: 1,
      audioBitrate: 32000,
      sampleRate: _audioSampleRate,
      filepath: outputPath,
    );

    _silentAudioFrame = Uint8List((_audioSampleRate * 1 * 2) ~/ _fps);

    _timer = Timer.periodic(
      _captureInterval,
      (_) => _captureFrame(repaintBoundaryKey),
    );
  }

  Future<void> _captureFrame(GlobalKey key) async {
    if (_busyCapturing) return;
    _busyCapturing = true;
    try {
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return;

      // toImage() hace su propio assert(!debugNeedsPaint) en modo debug si
      // el boundary está repintando justo en este instante — se deja que lo
      // atrape el catch de abajo (que ya existe para justo este tipo de
      // fallo puntual) en vez de leer debugNeedsPaint nosotros mismos: ese
      // getter solo asigna su resultado dentro de un assert(), así que
      // llamarlo fuera de modo debug lanzaría LateInitializationError.
      final image = await renderObject.toImage(pixelRatio: 1.0);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData == null) return;

        final bytes = byteData.buffer.asUint8List();
        // El tamaño capturado debe coincidir exacto con lo configurado en
        // setup(). No debería cambiar — la app está bloqueada a portrait —
        // pero si pasara, se descarta el cuadro en vez de romper el encoder.
        if (bytes.length != _width * _height * 4) return;

        await FlutterQuickVideoEncoder.appendVideoFrame(bytes);
        await FlutterQuickVideoEncoder.appendAudioFrame(_silentAudioFrame);
      } finally {
        image.dispose();
      }
    } catch (e) {
      // Un cuadro individual puede fallar (p.ej. boundary repintando justo
      // en ese instante); se descarta y se sigue con el siguiente en vez de
      // tumbar toda la grabación.
      debugPrint('[Fisiometric] Cuadro de overlay descartado: $e');
    } finally {
      _busyCapturing = false;
    }
  }

  /// Detiene la captura y cierra el archivo. Espera cualquier cuadro en
  /// vuelo antes de llamar a `finish()` para no cerrar el encoder a medias.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    while (_busyCapturing) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    await FlutterQuickVideoEncoder.finish();
  }
}
