import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/pose/body_view.dart';
import '../../core/utils/session_naming.dart';
import '../../models/recording_mode.dart';
import '../../models/session_metadata.dart';
import '../../services/camera/camera_service.dart';
import '../../services/export/session_exporter.dart';
import '../../services/storage/session_storage_service.dart';
import '../../theme/app_colors.dart';
import '../exercises/exercise_catalog_screen.dart';
import '../sessions/sessions_list_screen.dart';
import 'controllers/clean_video_recorder.dart';
import 'controllers/measurement_controller.dart';
import 'controllers/overlay_video_recorder.dart';
import 'widgets/angle_hud_panel.dart';
import 'widgets/body_view_toggle.dart';
import 'widgets/permission_gate.dart';
import 'widgets/record_button.dart';
import 'widgets/recording_mode_toggle.dart';
import 'widgets/skeleton_painter.dart';

class MeasureScreen extends StatelessWidget {
  const MeasureScreen({super.key, this.initialView = BodyView.frontal});

  /// Vista con la que arranca la medición — normalmente `frontal` (entrada
  /// por defecto), o la vista asociada al ejercicio elegido cuando se llega
  /// desde ExerciseDemoScreen.
  final BodyView initialView;

  @override
  Widget build(BuildContext context) {
    return PermissionGate(child: _CameraView(initialView: initialView));
  }
}

class _CameraView extends StatefulWidget {
  const _CameraView({required this.initialView});

  final BodyView initialView;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> with WidgetsBindingObserver {
  static const String _videoFileName = 'video.mp4';

  final CameraService _cameraService = CameraService();
  final MeasurementController _measurementController = MeasurementController();
  final CleanVideoRecorder _cleanRecorder = const CleanVideoRecorder();
  final OverlayVideoRecorder _overlayRecorder = OverlayVideoRecorder();
  final SessionStorageService _storageService = SessionStorageService();
  final SessionExporter _exporter = const SessionExporter();
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  late Future<void> _initFuture;
  RecordButtonState _recordState = RecordButtonState.idle;

  String? _sessionId;
  Directory? _sessionDir;
  DateTime? _sessionStartedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _measurementController.view = widget.initialView;
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    // Cámara y detector de pose son independientes entre sí — se inicializan
    // en paralelo para no sumar sus tiempos de arranque.
    final results = await Future.wait([
      // Cámara frontal por defecto: la idea es que el paciente pueda
      // colocar y ver el teléfono por sí mismo (uso autónomo, sin que
      // alguien más tenga que sostenerlo y apuntar con la trasera).
      _cameraService.initialize(preferredLens: CameraLensDirection.front),
      _measurementController.initializePoseDetector(),
    ]);
    final controller = results[0] as CameraController;

    _measurementController.sensorOrientation = controller.description.sensorOrientation;
    // Se lee la cámara que efectivamente quedó inicializada (no se asume
    // que "front" siempre esté disponible — CameraService cae a la primera
    // cámara del dispositivo si no hay frontal).
    _measurementController.isFrontFacing =
        controller.description.lensDirection == CameraLensDirection.front;
    await controller.startImageStream(_measurementController.handleCameraImage);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _measurementController.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.paused) {
      _handleAppPaused(controller);
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResumed(controller);
    }
  }

  Future<void> _handleAppPaused(CameraController controller) async {
    if (_recordState == RecordButtonState.recording &&
        _measurementController.mode == RecordingMode.overlayBurned) {
      // El pipeline de RepaintBoundary depende de que la app siga
      // renderizando activamente — no sobrevive bien el segundo plano, así
      // que se detiene y se guarda lo capturado hasta ahora en vez de
      // arriesgar un encoder colgado o un archivo corrupto. A diferencia
      // del botón (ver _toggleRecording), aquí no hay UI que muestre un
      // error, así que cualquier fallo solo se registra y se resetea el
      // estado — nunca debe escapar como excepción no manejada.
      try {
        await _stopRecordingAndSave(controller);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La grabación se detuvo porque la app pasó a segundo plano.',
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('[Fisiometric] Error al detener grabación en segundo plano: $e');
        _measurementController.endRecordingSession();
        if (mounted) setState(() => _recordState = RecordButtonState.idle);
      }
      return;
    }

    // Fuera de grabación, se detiene el streaming en vivo para no gastar
    // CPU/batería en inferencia de pose mientras la app no es visible. El
    // modo limpio en curso no se toca: la grabación nativa persiste sola
    // (`enablePersistentRecording`) y solo se pausa el muestreo de ángulos.
    if (_recordState == RecordButtonState.idle && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  Future<void> _handleAppResumed(CameraController controller) async {
    if (_recordState == RecordButtonState.idle && !controller.value.isStreamingImages) {
      await controller.startImageStream(_measurementController.handleCameraImage);
    }
  }

  void _retry() {
    setState(() {
      _initFuture = _initialize();
    });
  }

  Future<void> _toggleRecording() async {
    final controller = _cameraService.controller;
    if (controller == null) return;

    try {
      if (_recordState == RecordButtonState.idle) {
        await _startRecording(controller);
      } else if (_recordState == RecordButtonState.recording) {
        await _stopRecordingAndSave(controller);
      }
    } catch (e) {
      // Por si el fallo dejó al controller pensando que sigue grabando.
      _measurementController.endRecordingSession();
      if (!mounted) return;
      setState(() => _recordState = RecordButtonState.idle);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ocurrió un error: $e')));
    }
  }

  Future<void> _startRecording(CameraController controller) async {
    final now = DateTime.now();
    final sessionId = sessionIdFor(now);
    final dir = await _storageService.createSessionDirectory(sessionId);
    _sessionId = sessionId;
    _sessionDir = dir;
    _sessionStartedAt = now;

    _measurementController.beginRecordingSession();
    setState(() => _recordState = RecordButtonState.recording);

    if (_measurementController.mode == RecordingMode.clean) {
      final streamingLive = await _cleanRecorder.start(
        controller,
        _measurementController.handleCameraImage,
      );
      if (!streamingLive && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Este dispositivo no admite medir en vivo mientras graba: '
              'el video se guardará sin ángulos sincronizados en esta toma.',
            ),
          ),
        );
      }
    } else {
      // Modo overlay quemado: la cámara sigue en streaming plano (nunca se
      // toca aquí); solo se arranca la captura propia del RepaintBoundary.
      await _overlayRecorder.start(
        repaintBoundaryKey: _repaintBoundaryKey,
        outputPath: '${dir.path}/$_videoFileName',
      );
    }
  }

  Future<void> _stopRecordingAndSave(CameraController controller) async {
    setState(() => _recordState = RecordButtonState.saving);

    final dir = _sessionDir!;
    final videoPath = '${dir.path}/$_videoFileName';

    if (_measurementController.mode == RecordingMode.clean) {
      await _cleanRecorder.stop(
        controller,
        videoPath,
        _measurementController.handleCameraImage,
      );
    } else {
      await _overlayRecorder.stop();
    }

    final samples = _measurementController.endRecordingSession();
    final durationMs = samples.isEmpty ? 0 : samples.last.timestampMs;

    final view = _measurementController.view;
    await _exporter.writeCsv('${dir.path}/datos.csv', samples, view);
    await _exporter.writeXlsx('${dir.path}/datos.xlsx', samples, view);

    final rawStats = _exporter.computeJointStats(samples);
    final metadata = SessionMetadata(
      id: _sessionId!,
      startedAt: _sessionStartedAt!,
      mode: _measurementController.mode,
      view: view,
      durationMs: durationMs,
      sampleCount: samples.length,
      jointStats: rawStats.map(
        (k, v) => MapEntry(k, JointStats(min: v.min, max: v.max, avg: v.avg)),
      ),
      velocityStats: _exporter.computeVelocityStats(samples),
      symmetryStats: _exporter.computeSymmetryStats(samples, view),
      videoFileName: _videoFileName,
    );
    await File('${dir.path}/session.json').writeAsString(metadata.toJsonString());

    if (!mounted) return;
    setState(() => _recordState = RecordButtonState.idle);
    var message = 'Sesión guardada: $_sessionId';
    if (kDebugMode && _measurementController.mode == RecordingMode.overlayBurned) {
      // Diagnóstico temporal (ver overlay_video_recorder.dart): si el video
      // no reproduce, este número dice si el problema es que casi ningún
      // cuadro se logró capturar (revisar lastError) o que sí se capturaron
      // pero el archivo igual quedó corrupto (otro tipo de bug).
      message +=
          '\nOverlay: ${_overlayRecorder.framesAppended}/${_overlayRecorder.framesAttempted} cuadros'
          '${_overlayRecorder.lastError != null ? ' — error: ${_overlayRecorder.lastError}' : ''}';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Fisiometric'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Sesiones guardadas',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SessionsListScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fitness_center_outlined),
            tooltip: 'Ejercicios',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExerciseCatalogScreen()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.orangeAccent),
            );
          }
          if (snapshot.hasError) {
            return _InitErrorMessage(error: snapshot.error!, onRetry: _retry);
          }
          return _MeasureStack(
            controller: _cameraService.controller!,
            measurementController: _measurementController,
            recordState: _recordState,
            onToggleRecording: _toggleRecording,
            repaintBoundaryKey: _repaintBoundaryKey,
          );
        },
      ),
    );
  }
}

class _MeasureStack extends StatelessWidget {
  const _MeasureStack({
    required this.controller,
    required this.measurementController,
    required this.recordState,
    required this.onToggleRecording,
    required this.repaintBoundaryKey,
  });

  final CameraController controller;
  final MeasurementController measurementController;
  final RecordButtonState recordState;
  final VoidCallback onToggleRecording;
  final GlobalKey repaintBoundaryKey;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          // Envuelve cámara + esqueleto (no el HUD numérico, ver Fase 6) en
          // un RepaintBoundary propio: es lo que OverlayVideoRecorder
          // captura cuadro a cuadro en el modo "overlay quemado".
          child: RepaintBoundary(
            key: repaintBoundaryKey,
            child: CameraPreview(
              controller,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Solo para el panel de diagnóstico — ver comentario en
                  // MeasurementController.lastCanvasSize.
                  measurementController.lastCanvasSize = constraints.biggest;
                  return AnimatedBuilder(
                    animation: measurementController,
                    builder: (context, _) => CustomPaint(
                      painter: SkeletonPainter(
                        frame: measurementController.latestPose,
                        angles: measurementController.latestAngles,
                        view: measurementController.view,
                        isFrontFacing: measurementController.isFrontFacing,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (kDebugMode)
          Positioned(
            top: 16,
            left: 16,
            child: AnimatedBuilder(
              animation: measurementController,
              builder: (context, _) =>
                  _DiagnosticsOverlay(controller: measurementController),
            ),
          ),
        Positioned(
          top: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: measurementController,
            builder: (context, _) => AngleHudPanel(
              angles: measurementController.latestAngles,
              velocity: measurementController.latestVelocity,
              symmetry: measurementController.latestSymmetry,
              view: measurementController.view,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: measurementController,
                builder: (context, _) => BodyViewToggle(
                  view: measurementController.view,
                  locked: recordState != RecordButtonState.idle,
                  onChanged: (newView) => measurementController.view = newView,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: measurementController,
                builder: (context, _) => RecordingModeToggle(
                  mode: measurementController.mode,
                  locked: recordState != RecordButtonState.idle,
                  onChanged: (newMode) => measurementController.mode = newMode,
                ),
              ),
              const SizedBox(height: 16),
              RecordButton(state: recordState, onPressed: onToggleRecording),
            ],
          ),
        ),
      ],
    );
  }
}

/// Overlay temporal (solo `kDebugMode`) para diagnosticar en pantalla, sin
/// necesitar logs por USB, por qué el detector de pose no encuentra a
/// nadie: distingue "nunca procesa un frame" (framesProcesados en 0, revisar
/// formato/excepciones) de "procesa pero no detecta persona" (framesConPose
/// en 0 con framesProcesados subiendo, revisar rotación/encuadre).
class _DiagnosticsOverlay extends StatelessWidget {
  const _DiagnosticsOverlay({required this.controller});

  final MeasurementController controller;

  @override
  Widget build(BuildContext context) {
    final frontal = controller.isFrontFacing ? 'sí' : 'no';
    final error = controller.lastPoseError;
    final pose = controller.latestPose;
    final canvas = controller.lastCanvasSize;
    final poseAspect = pose.imageHeight == 0
        ? null
        : pose.imageWidth / pose.imageHeight;
    final canvasAspect = canvas == null || canvas.height == 0
        ? null
        : canvas.width / canvas.height;
    final lines = [
      'frontal: $frontal',
      'sensor: ${controller.sensorOrientation}° · rot: ${controller.rotationUsed}°',
      'frames: ${controller.framesProcessed} · con pose: ${controller.framesWithPose}',
      'pose img: ${pose.imageWidth}x${pose.imageHeight}'
          '${poseAspect != null ? ' (${poseAspect.toStringAsFixed(3)})' : ''}',
      'canvas: ${canvas == null ? '?' : '${canvas.width.round()}x${canvas.height.round()}'}'
          '${canvasAspect != null ? ' (${canvasAspect.toStringAsFixed(3)})' : ''}',
      if (error != null) 'error: ${error.length > 220 ? error.substring(0, 220) : error}',
    ];
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            Text(
              line,
              style: TextStyle(
                color: line.startsWith('error:')
                    ? Colors.redAccent
                    : Colors.greenAccent,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

class _InitErrorMessage extends StatelessWidget {
  const _InitErrorMessage({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            size: 64,
            color: AppColors.orangeAccent,
          ),
          const SizedBox(height: 16),
          const Text(
            'No se pudo iniciar la medición',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
