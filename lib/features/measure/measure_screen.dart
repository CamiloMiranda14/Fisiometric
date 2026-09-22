import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/pose/angle_calculator.dart';
import '../../core/pose/body_outline_images.dart';
import '../../core/pose/body_region.dart';
import '../../core/pose/body_view.dart';
import '../../core/pose/positioning_alignment.dart';
import '../../core/utils/session_naming.dart';
import '../../models/recording_mode.dart';
import '../../models/session_metadata.dart';
import '../../services/camera/camera_service.dart';
import '../../services/export/session_exporter.dart';
import '../../services/notifications/daily_reminder_service.dart';
import '../../services/patient/patient_profile_service.dart';
import '../../services/storage/session_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/widgets/logo_loading_view.dart';
import '../exercises/exercise_catalog.dart';
import '../exercises/exercise_catalog_screen.dart';
import '../sessions/sessions_list_screen.dart';
import 'session_result_screen.dart';
import 'controllers/clean_video_recorder.dart';
import 'controllers/measurement_controller.dart';
import 'controllers/overlay_video_recorder.dart';
import 'widgets/angle_hud_panel.dart';
import 'widgets/body_view_toggle.dart';
import 'widgets/permission_gate.dart';
import 'widgets/positioning_guide_painter.dart';
import 'widgets/record_button.dart';
import 'widgets/skeleton_painter.dart';

class MeasureScreen extends StatelessWidget {
  const MeasureScreen({
    super.key,
    this.initialView = BodyView.frontal,
    this.patientName,
    this.region = BodyRegion.fullBody,
    this.exerciseId,
    this.trackedJoints,
  });

  /// Vista con la que arranca la medición — normalmente `frontal` (entrada
  /// por defecto), o la vista asociada al ejercicio elegido cuando se llega
  /// desde ExerciseDemoScreen.
  final BodyView initialView;

  /// Nombre/identificador del paciente, ingresado antes de llegar aquí (ver
  /// QuickTestViewScreen/ExerciseDemoScreen) — se guarda junto a cada
  /// sesión que se grabe en esta pantalla.
  final String? patientName;

  /// Qué parte del cuerpo dibuja la silueta guía — `fullBody` (por defecto,
  /// usado en "Prueba rápida") o la región del ejercicio elegido.
  final BodyRegion region;

  /// `Exercise.id` del catálogo, si se llegó desde ExerciseDemoScreen — se
  /// guarda junto a la sesión para asociarla a la patología en
  /// ProgressScreen. `null` en "Prueba rápida".
  final String? exerciseId;

  /// Fija explícitamente qué articulación(es) medir — usado por "Prueba
  /// rápida" (que no tiene un `exerciseId` del cual derivarlo). Si se da,
  /// tiene prioridad sobre lo que derivaría `exerciseId`; `null` con
  /// `exerciseId` también `null` no restringe nada ("todas las
  /// articulaciones").
  final Set<JointKind>? trackedJoints;

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      child: _CameraView(
        initialView: initialView,
        patientName: patientName,
        region: region,
        exerciseId: exerciseId,
        trackedJoints: trackedJoints,
      ),
    );
  }
}

class _CameraView extends StatefulWidget {
  const _CameraView({
    required this.initialView,
    this.patientName,
    required this.region,
    this.exerciseId,
    this.trackedJoints,
  });

  final BodyView initialView;
  final String? patientName;
  final BodyRegion region;
  final String? exerciseId;
  final Set<JointKind>? trackedJoints;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

/// Fases previas a la grabación en sí, entre tocar el botón y que empiece
/// realmente a grabar — ver MeasureScreen._onRecordButtonPressed.
enum _PreRecordPhase {
  /// No se tocó el botón todavía (o ya se canceló) — solo se ve la silueta
  /// guía, sin exigir nada.
  none,

  /// Se tocó el botón: esperando que el paciente se alinee con la silueta.
  waitingAlignment,

  /// Ya se alineó lo suficiente por un momento sostenido — cuenta regresiva
  /// antes de arrancar la grabación de verdad.
  countdown,
}

class _CameraViewState extends State<_CameraView> with WidgetsBindingObserver {
  static const String _videoFileName = 'video.mp4';

  /// Cuánto debe mantenerse alineado el paciente antes de arrancar la
  /// cuenta regresiva — evita que un roce momentáneo con la silueta
  /// dispare la grabación por accidente.
  static const Duration _sustainedAlignmentDuration = Duration(milliseconds: 700);
  static const int _countdownStartValue = 3;

  final CameraService _cameraService = CameraService();
  final MeasurementController _measurementController = MeasurementController();
  final CleanVideoRecorder _cleanRecorder = const CleanVideoRecorder();
  final OverlayVideoRecorder _overlayRecorder = OverlayVideoRecorder();
  final SessionStorageService _storageService = SessionStorageService();
  final SessionExporter _exporter = const SessionExporter();
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  late Future<void> _initFuture;
  late BodyOutlineImages _outlineImages;
  RecordButtonState _recordState = RecordButtonState.idle;

  String? _sessionId;
  Directory? _sessionDir;
  DateTime? _sessionStartedAt;

  _PreRecordPhase _preRecordPhase = _PreRecordPhase.none;
  bool _isAligned = false;
  int _countdownValue = _countdownStartValue;
  DateTime? _alignedSince;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _measurementController.view = widget.initialView;
    _measurementController.region = widget.region;
    _measurementController.trackedJoints =
        widget.trackedJoints ?? trackedJointsForExerciseId(widget.exerciseId);
    _measurementController.addListener(_onMeasurementUpdate);
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
      loadBodyOutlineImages(),
    ]);
    final controller = results[0] as CameraController;
    _outlineImages = results[2] as BodyOutlineImages;

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
    _countdownTimer?.cancel();
    _measurementController.removeListener(_onMeasurementUpdate);
    _measurementController.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  /// Corre en cada frame procesado en vivo (ver MeasurementController) —
  /// solo hace algo mientras el gate de pre-grabación está activo. Evita
  /// llamar `setState` en cada frame salvo que algo realmente visible
  /// cambie (la transición alineado/no-alineado), para no repintar toda la
  /// pantalla en cada cuadro — el resto del estado (`_alignedSince`) se
  /// actualiza en silencio.
  void _onMeasurementUpdate() {
    if (_preRecordPhase == _PreRecordPhase.none) return;

    final canvasSize = _measurementController.lastCanvasSize;
    final aligned = canvasSize != null &&
        isAlignedWithGuide(
          frame: _measurementController.latestPose,
          view: _measurementController.view,
          region: widget.region,
          canvasSize: canvasSize,
          isFrontFacing: _measurementController.isFrontFacing,
        );

    if (aligned != _isAligned) {
      setState(() => _isAligned = aligned);
    }

    if (_preRecordPhase == _PreRecordPhase.countdown) {
      // Si se desalinea a mitad de la cuenta regresiva, se cancela y se
      // vuelve a esperar — mejor eso que arrancar una toma mal encuadrada.
      if (!aligned) _cancelCountdownBackToWaiting();
      return;
    }

    if (!aligned) {
      _alignedSince = null;
      return;
    }
    _alignedSince ??= DateTime.now();
    if (DateTime.now().difference(_alignedSince!) >= _sustainedAlignmentDuration) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _alignedSince = null;
    setState(() {
      _preRecordPhase = _PreRecordPhase.countdown;
      _countdownValue = _countdownStartValue;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue <= 1) {
        timer.cancel();
        _countdownTimer = null;
        _preRecordPhase = _PreRecordPhase.none;
        _toggleRecording();
        return;
      }
      setState(() => _countdownValue--);
    });
  }

  void _cancelCountdownBackToWaiting() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() => _preRecordPhase = _PreRecordPhase.waitingAlignment);
  }

  /// Cancela el gate por completo (botón tocado de nuevo mientras se
  /// esperaba alineación o corría la cuenta regresiva) — vuelve a
  /// `idle` sin haber empezado a grabar nada.
  void _cancelPreRecordGate() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _alignedSince = null;
    setState(() {
      _preRecordPhase = _PreRecordPhase.none;
      _isAligned = false;
    });
  }

  /// Botón principal: si el gate ya está activo, tocarlo de nuevo lo
  /// cancela; si está en reposo, lo arranca (en vez de grabar directo) o
  /// detiene la grabación en curso — ver _toggleRecording.
  void _onRecordButtonPressed() {
    if (_preRecordPhase != _PreRecordPhase.none) {
      _cancelPreRecordGate();
      return;
    }
    if (_recordState == RecordButtonState.recording) {
      _toggleRecording();
      return;
    }
    if (_recordState == RecordButtonState.idle) {
      setState(() => _preRecordPhase = _PreRecordPhase.waitingAlignment);
    }
  }

  /// Salvavidas por si la detección no logra confirmar alineación (mala
  /// luz, encuadre atípico, etc.) — empieza a grabar directo, sin esperar.
  void _forceStartRecording() {
    _cancelPreRecordGate();
    _toggleRecording();
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

    final rawStats = _exporter.computeJointStats(samples);
    final metadata = SessionMetadata(
      id: _sessionId!,
      startedAt: _sessionStartedAt!,
      mode: _measurementController.mode,
      view: view,
      region: widget.region,
      durationMs: durationMs,
      sampleCount: samples.length,
      jointStats: rawStats.map(
        (k, v) => MapEntry(k, JointStats(min: v.min, max: v.max, avg: v.avg)),
      ),
      velocityStats: _exporter.computeVelocityStats(samples),
      videoFileName: _videoFileName,
      patientName: widget.patientName,
      exerciseId: widget.exerciseId,
    );
    await File('${dir.path}/session.json').writeAsString(metadata.toJsonString());

    // No se espera — reprograma el recordatorio diario (ver
    // DailyReminderService) ahora que hoy ya quedó medido, sin demorar la
    // navegación a la pantalla de resultados.
    unawaited(
      PatientProfileService().loadLast().then((profile) {
        if (profile != null) DailyReminderService().refresh(profile);
      }),
    );

    if (!mounted) return;
    setState(() => _recordState = RecordButtonState.idle);
    if (kDebugMode && _measurementController.mode == RecordingMode.overlayBurned) {
      // Diagnóstico temporal (ver overlay_video_recorder.dart): si el video
      // no reproduce, este número dice si el problema es que casi ningún
      // cuadro se logró capturar (revisar lastError) o que sí se capturaron
      // pero el archivo igual quedó corrupto (otro tipo de bug).
      debugPrint(
        '[Fisiometric] Overlay: ${_overlayRecorder.framesAppended}/'
        '${_overlayRecorder.framesAttempted} cuadros'
        '${_overlayRecorder.lastError != null ? ' — error: ${_overlayRecorder.lastError}' : ''}',
      );
    }
    // Al terminar de grabar, se lleva directo a la retroalimentación (rango
    // máximo alcanzado) en vez de solo un aviso — desde ahí el paciente
    // elige repetir o ver los resultados completos.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SessionResultScreen(dir: dir, metadata: metadata)),
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
              MaterialPageRoute(
                builder: (_) => ExerciseCatalogScreen(patientName: widget.patientName ?? ''),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LogoLoadingView(message: 'Iniciando cámara...');
          }
          if (snapshot.hasError) {
            return _InitErrorMessage(error: snapshot.error!, onRetry: _retry);
          }
          return _MeasureStack(
            controller: _cameraService.controller!,
            measurementController: _measurementController,
            recordState: _recordState,
            preRecordPhase: _preRecordPhase,
            isAligned: _isAligned,
            countdownValue: _countdownValue,
            region: widget.region,
            outlineImages: _outlineImages,
            onToggleRecording: _onRecordButtonPressed,
            onForceRecord: _forceStartRecording,
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
    required this.preRecordPhase,
    required this.isAligned,
    required this.countdownValue,
    required this.region,
    required this.outlineImages,
    required this.onToggleRecording,
    required this.onForceRecord,
    required this.repaintBoundaryKey,
  });

  final CameraController controller;
  final MeasurementController measurementController;
  final RecordButtonState recordState;
  final _PreRecordPhase preRecordPhase;
  final bool isAligned;
  final int countdownValue;
  final BodyRegion region;
  final BodyOutlineImages outlineImages;
  final VoidCallback onToggleRecording;
  final VoidCallback onForceRecord;
  final GlobalKey repaintBoundaryKey;

  bool get _gateActive => preRecordPhase != _PreRecordPhase.none;
  // Los controles se bloquean mientras graba Y mientras corre el gate de
  // alineación/cuenta regresiva — no tiene sentido cambiar de vista o modo
  // a mitad de cualquiera de los dos.
  bool get _controlsLocked => recordState != RecordButtonState.idle || _gateActive;

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
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Silueta guía: solo antes de grabar, para que el
                      // paciente se ubique a la distancia correcta. Se
                      // dibuja aparte del esqueleto real (que sigue
                      // corriendo en vivo debajo) para dar retroalimentación
                      // inmediata de qué tan bien está alineado.
                      if (recordState == RecordButtonState.idle)
                        CustomPaint(
                          painter: PositioningGuidePainter(
                            view: measurementController.view,
                            isAligned: isAligned,
                            region: region,
                            images: outlineImages,
                          ),
                        ),
                      AnimatedBuilder(
                        animation: measurementController,
                        builder: (context, _) => CustomPaint(
                          painter: SkeletonPainter(
                            frame: measurementController.latestPose,
                            angles: measurementController.latestAngles,
                            view: measurementController.view,
                            region: region,
                            isFrontFacing: measurementController.isFrontFacing,
                            trackedJoints: measurementController.trackedJoints,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: measurementController,
            builder: (context, _) => AngleHudPanel(
              angles: measurementController.latestAngles,
              velocity: measurementController.latestVelocity,
              view: measurementController.view,
              region: region,
              trackedJoints: measurementController.trackedJoints,
            ),
          ),
        ),
        if (_gateActive)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: _PreRecordBanner(
                phase: preRecordPhase,
                isAligned: isAligned,
                onForceRecord: onForceRecord,
              ),
            ),
          ),
        // Aviso de movimiento brusco: solo mientras se está grabando de
        // verdad (no durante el gate de alineación, donde el paciente
        // todavía no está haciendo el ejercicio) — ver
        // MeasurementController.isMovingTooFast.
        if (recordState == RecordButtonState.recording)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: measurementController,
                builder: (context, _) => measurementController.isMovingTooFast
                    ? const _FastMovementWarning()
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        // Número de cuenta regresiva: aparte del mensaje de arriba y bien
        // grande/centrado, para que se lea de un vistazo sin acercarse a la
        // pantalla — mismo espíritu que el temporizador de una cámara.
        if (preRecordPhase == _PreRecordPhase.countdown)
          Positioned.fill(
            child: Center(child: _CountdownBadge(value: countdownValue)),
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
                  locked: _controlsLocked,
                  onChanged: (newView) => measurementController.view = newView,
                ),
              ),
              const SizedBox(height: 16),
              RecordButton(
                // Mientras el gate está activo, el botón se muestra como
                // "detener" (mismo ícono/color que grabando) — tocarlo
                // cancela el gate, ver _onRecordButtonPressed.
                state: _gateActive ? RecordButtonState.recording : recordState,
                onPressed: onToggleRecording,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Aviso de que el paciente está moviendo la articulación trackeada más
/// rápido de lo recomendable (ver MeasurementController.isMovingTooFast) —
/// aparece y desaparece solo, sin que el paciente tenga que hacer nada, ni
/// interrumpe la grabación.
class _FastMovementWarning extends StatelessWidget {
  const _FastMovementWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.orangeAccent.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed_outlined, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'Muévete más despacio',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Mensaje sobre la silueta guía mientras corre el gate de pre-grabación:
/// "ubícate" mientras se espera alineación, "¡posición correcta!" durante la
/// cuenta regresiva (el número en sí lo muestra _CountdownBadge, centrado y
/// grande, aparte de este mensaje). Incluye un botón de salvavidas para
/// grabar sin esperar, por si la detección no logra confirmar alineación.
class _PreRecordBanner extends StatelessWidget {
  const _PreRecordBanner({
    required this.phase,
    required this.isAligned,
    required this.onForceRecord,
  });

  final _PreRecordPhase phase;
  final bool isAligned;
  final VoidCallback onForceRecord;

  @override
  Widget build(BuildContext context) {
    final isCountdown = phase == _PreRecordPhase.countdown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isCountdown ? '¡Posición correcta!' : 'Ubícate dentro de la silueta',
            style: TextStyle(
              color: isAligned ? AppColors.success : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onForceRecord,
            child: const Text(
              'Grabar sin esperar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// Número de cuenta regresiva, grande y centrado en pantalla — mismo
/// espíritu que el temporizador de una app de cámara.
class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: AppColors.success, width: 4),
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 88,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
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
