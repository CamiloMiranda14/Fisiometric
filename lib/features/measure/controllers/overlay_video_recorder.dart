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
/// pipeline más delicado de la app. Si el capturado no llega al ritmo
/// configurado en `_fps` (frecuente en este pipeline), el cuadro se repite
/// las veces necesarias para cubrir el tiempo real transcurrido (ver
/// _captureFrame), así que el video queda a velocidad correcta aunque la
/// captura vaya más lenta que `_fps` — a costa de que un tramo lento del
/// video se vea "congelado" en vez de fluido. Ver angle_sample.timestampMs
/// para la sincronización real con los datos, que no depende de esto.
class OverlayVideoRecorder {
  static const int _fps = 20;
  static const int _audioSampleRate = 16000;
  static const Duration _captureInterval = Duration(milliseconds: 1000 ~/ _fps);

  Timer? _timer;
  bool _busyCapturing = false;
  String? _outputPath;
  int _width = 0;
  int _height = 0;
  DateTime? _lastAppendTime;

  // Diagnóstico (ver MeasureScreen._stopRecordingAndSave): cuántos cuadros
  // se intentaron capturar vs. cuántos se lograron anexar al encoder, y el
  // último error si alguno falló. `appendVideoFrame`/`appendAudioFrame`
  // descartan fallos en silencio a propósito (ver catch en _captureFrame)
  // para no tumbar la grabación por un cuadro suelto — pero si TODOS
  // fallan, el resultado es un mp4 sin cuadros de video, que no reproduce.
  int _framesAttempted = 0;
  int _framesAppended = 0;
  String? _lastError;

  int get framesAttempted => _framesAttempted;
  int get framesAppended => _framesAppended;
  String? get lastError => _lastError;

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

    // `FlutterQuickVideoEncoder.setup()` se pospone al primer cuadro
    // capturado (ver _captureFrame) en vez de llamarse aquí con
    // `renderObject.size.round()`: en dispositivo, ese tamaño "estimado"
    // antes de que se capture ningún cuadro no coincidía exacto con el
    // tamaño real que reportaba luego `toImage()` (visto en un Moto G47:
    // esperado 1178380 bytes, real 1181040) — probablemente por un cambio
    // de insets/UI del sistema entre medir y capturar. Usar el tamaño que
    // el primer `ui.Image` reporta de sí mismo es la fuente de verdad, no
    // una medición previa que puede quedar desactualizada.
    _outputPath = outputPath;
    _width = 0;
    _height = 0;
    _framesAttempted = 0;
    _framesAppended = 0;
    _lastError = null;
    _lastAppendTime = null;

    _silentAudioFrame = Uint8List((_audioSampleRate * 1 * 2) ~/ _fps);

    _timer = Timer.periodic(
      _captureInterval,
      (_) => _captureFrame(repaintBoundaryKey),
    );
  }

  Future<void> _captureFrame(GlobalKey key) async {
    if (_busyCapturing) return;
    _busyCapturing = true;
    _framesAttempted++;
    try {
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        _lastError = 'RepaintBoundary no montado';
        return;
      }

      // toImage() hace su propio assert(!debugNeedsPaint) en modo debug si
      // el boundary está repintando justo en este instante — se deja que lo
      // atrape el catch de abajo (que ya existe para justo este tipo de
      // fallo puntual) en vez de leer debugNeedsPaint nosotros mismos: ese
      // getter solo asigna su resultado dentro de un assert(), así que
      // llamarlo fuera de modo debug lanzaría LateInitializationError.
      final image = await renderObject.toImage(pixelRatio: 1.0);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData == null) {
          _lastError = 'toByteData devolvió null';
          return;
        }

        final bytes = byteData.buffer.asUint8List();

        if (_width == 0) {
          // Primer cuadro: recién aquí se conoce el tamaño real, así que
          // recién aquí se arranca el encoder (ver comentario en start()).
          //
          // Se fuerza a par: YUV 4:2:0 necesita ancho/alto pares para que
          // los planos de croma (mitad de resolución) cuadren exacto — un
          // ancho o alto impar hace que la conversión RGBA→YUV420 de
          // flutter_quick_video_encoder reviente con un índice fuera de
          // rango (confirmado en dispositivo: "ArrayIndexOutOfBoundsException:
          // length=442890; index=442890" en su rgbaToYuv420Planar). Se
          // recorta 1 píxel en vez de arriesgar ese crash cada vez.
          _width = image.width - (image.width.isOdd ? 1 : 0);
          _height = image.height - (image.height.isOdd ? 1 : 0);
          await FlutterQuickVideoEncoder.setup(
            width: _width,
            height: _height,
            fps: _fps,
            videoBitrate: 4 * 1000 * 1000,
            profileLevel: ProfileLevel.any,
            audioChannels: 1,
            audioBitrate: 32000,
            sampleRate: _audioSampleRate,
            filepath: _outputPath!,
          );
        }

        if (image.width < _width || image.height < _height) {
          // El tamaño cambió a mitad de la grabación (no debería pasar —
          // la app está bloqueada a portrait — pero si pasa, se descarta
          // el cuadro en vez de romper el encoder, que ya quedó
          // configurado para el tamaño del primer cuadro).
          _lastError =
              'tamaño de cuadro cambió a mitad de grabación: ${image.width}x${image.height} (se esperaba al menos ${_width}x$_height)';
          return;
        }

        final croppedBytes = _cropToEncoderSize(bytes, srcWidth: image.width);

        // El video queda a la velocidad correcta contando cuánto tiempo
        // real pasó desde el cuadro anterior y repitiendo este cuadro las
        // veces necesarias para cubrirlo, en vez de asumir que cada cuadro
        // duró exactamente 1/fps — si la captura va más lenta que _fps
        // (normal en este pipeline), asumir eso deja el video "acelerado"
        // respecto al tiempo real (cada cuadro repetido dura lo mismo que
        // uno capturado normal, así que no se nota como cuadros duplicados,
        // solo como que el video dura lo que debe).
        final now = DateTime.now();
        final lastAppendTime = _lastAppendTime;
        final slots = lastAppendTime == null
            ? 1
            : ((now.difference(lastAppendTime).inMilliseconds / _captureInterval.inMilliseconds)
                      .round())
                  .clamp(1, _fps * 2);
        // El límite de arriba (2 segundos de cuadros repetidos como
        // máximo) evita que una pausa larga (p.ej. la app pasó a segundo
        // plano) llene el video de miles de cuadros duplicados.
        for (var i = 0; i < slots; i++) {
          await FlutterQuickVideoEncoder.appendVideoFrame(croppedBytes);
          await FlutterQuickVideoEncoder.appendAudioFrame(_silentAudioFrame);
        }
        _lastAppendTime = now;
        _framesAppended++;
      } finally {
        image.dispose();
      }
    } catch (e) {
      // Un cuadro individual puede fallar (p.ej. boundary repintando justo
      // en ese instante); se descarta y se sigue con el siguiente en vez de
      // tumbar toda la grabación.
      _lastError = e.toString();
      debugPrint('[Fisiometric] Cuadro de overlay descartado: $e');
    } finally {
      _busyCapturing = false;
    }
  }

  /// Recorta un cuadro RGBA de ancho [srcWidth] a las dimensiones ([_width],
  /// [_height]) con las que se configuró el encoder — ver comentario en
  /// _captureFrame sobre por qué esas dimensiones deben ser pares.
  Uint8List _cropToEncoderSize(Uint8List bytes, {required int srcWidth}) {
    if (srcWidth == _width && bytes.length == _width * _height * 4) {
      return bytes;
    }
    final out = Uint8List(_width * _height * 4);
    for (var row = 0; row < _height; row++) {
      final srcStart = row * srcWidth * 4;
      out.setRange(row * _width * 4, row * _width * 4 + _width * 4, bytes, srcStart);
    }
    return out;
  }

  /// Detiene la captura y cierra el archivo. Espera cualquier cuadro en
  /// vuelo antes de llamar a `finish()` para no cerrar el encoder a medias.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    while (_busyCapturing) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    // Si ni un solo cuadro llegó a configurar el encoder (ver
    // _captureFrame), no hay nada que cerrar — llamar finish() sin un
    // setup() previo fallaría.
    if (_width == 0) return;
    await FlutterQuickVideoEncoder.finish();
  }
}
