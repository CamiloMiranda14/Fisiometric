import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/utils/session_naming.dart';
import '../../models/recording_mode.dart';
import '../../models/session_metadata.dart';
import '../../services/camera/camera_service.dart';
import '../../services/export/session_exporter.dart';
import '../../services/storage/session_storage_service.dart';
import '../../theme/app_colors.dart';
import '../sessions/sessions_list_screen.dart';
import 'controllers/clean_video_recorder.dart';
import 'controllers/measurement_controller.dart';
import 'controllers/overlay_video_recorder.dart';
import 'widgets/angle_hud_panel.dart';
import 'widgets/permission_gate.dart';
import 'widgets/record_button.dart';
import 'widgets/recording_mode_toggle.dart';
import 'widgets/skeleton_painter.dart';

class MeasureScreen extends StatelessWidget {
  const MeasureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PermissionGate(child: _CameraView());
  }
}

class _CameraView extends StatefulWidget {
  const _CameraView();

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
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    // Cámara y detector de pose son independientes entre sí — se inicializan
    // en paralelo para no sumar sus tiempos de arranque.
    final results = await Future.wait([
      _cameraService.initialize(),
      _measurementController.initializePoseDetector(),
    ]);
    final controller = results[0] as CameraController;

    _measurementController.sensorOrientation = controller.description.sensorOrientation;
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

    await _exporter.writeCsv('${dir.path}/datos.csv', samples);
    await _exporter.writeXlsx('${dir.path}/datos.xlsx', samples);

    final rawStats = _exporter.computeJointStats(samples);
    final metadata = SessionMetadata(
      id: _sessionId!,
      startedAt: _sessionStartedAt!,
      mode: _measurementController.mode,
      durationMs: durationMs,
      sampleCount: samples.length,
      jointStats: rawStats.map(
        (k, v) => MapEntry(k, JointStats(min: v.min, max: v.max, avg: v.avg)),
      ),
      videoFileName: _videoFileName,
    );
    await File('${dir.path}/session.json').writeAsString(metadata.toJsonString());

    if (!mounted) return;
    setState(() => _recordState = RecordButtonState.idle);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sesión guardada: $_sessionId')));
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
              child: AnimatedBuilder(
                animation: measurementController,
                builder: (context, _) => CustomPaint(
                  painter: SkeletonPainter(
                    frame: measurementController.latestPose,
                    angles: measurementController.latestAngles,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: measurementController,
            builder: (context, _) =>
                AngleHudPanel(angles: measurementController.latestAngles),
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
