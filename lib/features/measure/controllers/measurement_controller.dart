import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../../core/pose/angle_calculator.dart';
import '../../../core/pose/angular_velocity_calculator.dart';
import '../../../core/pose/body_region.dart';
import '../../../core/pose/body_view.dart';
import '../../../core/pose/camera_rotation.dart';
import '../../../models/angle_sample.dart';
import '../../../models/joint_angles.dart';
import '../../../models/joint_angular_velocity.dart';
import '../../../models/pose_frame.dart';
import '../../../models/recording_mode.dart';
import '../../../services/pose/mediapipe_pose_detection_service.dart';
import '../../../services/pose/pose_detection_service.dart';
import 'angle_sample_buffer.dart';

/// Orquesta la detección de pose en vivo para la vista de medición: recibe
/// frames de cámara, los pasa al detector y expone el último resultado.
///
/// El guardia [_busyProcessing] es el mecanismo de throttling: si un frame
/// anterior todavía se está procesando, el nuevo frame se descarta en
/// silencio en vez de encolarse. Así la tasa de muestreo se adapta sola a
/// la velocidad real del dispositivo, sin acumular retraso.
class MeasurementController extends ChangeNotifier {
  MeasurementController({PoseDetectionService? poseService})
    : _poseService = poseService ?? MediaPipePoseDetectionService();

  final PoseDetectionService _poseService;
  final AngleSampleBuffer _buffer = AngleSampleBuffer();
  final Stopwatch _recordingStopwatch = Stopwatch();

  bool _busyProcessing = false;

  /// Ángulo (0/90/180/270) que el detector debe aplicar para enderezar la
  /// imagen del sensor — se fija una vez, al iniciar la cámara (ver
  /// CameraDescription.sensorOrientation), y no cambia mientras la app está
  /// bloqueada a portrait.
  int sensorOrientation = 0;

  /// Si la cámara activa es la frontal — se fija una vez, al iniciar la
  /// cámara (ver CameraDescription.lensDirection). Importa para la
  /// rotación: ver PoseDetectionService.processCameraImage.
  bool isFrontFacing = false;

  /// Región del cuerpo del ejercicio activo — se fija una vez, al iniciar
  /// MeasureScreen (ver `widget.region`), y no cambia mientras dura la
  /// sesión (a diferencia de `view`, que sí se puede tocar). Anula los
  /// ángulos/keypoints que no pertenecen a esta región (ver
  /// `filterForRegion`) para que un ejercicio de tren superior no calcule
  /// ni muestre rodilla/tobillo, y viceversa.
  BodyRegion region = BodyRegion.fullBody;

  /// Qué articulaciones mide el ejercicio activo (ver
  /// `Exercise.trackedJoints`/`trackedJointsForExerciseId`) — se fija una
  /// vez, al iniciar MeasureScreen. `null` (p.ej. "Prueba rápida", sin
  /// ejercicio elegido) no restringe nada más allá de `region`. Anula los
  /// ángulos que la región sí permitiría pero este ejercicio en particular
  /// no mide — p.ej. abducción de hombro no muestra codo/muñeca aunque
  /// ambas sean "tren superior".
  Set<JointKind>? trackedJoints;

  /// Tamaño real (en píxeles lógicos) del lienzo donde se dibuja el
  /// esqueleto — lo fija MeasureScreen vía LayoutBuilder. Usado para
  /// revisar si el paciente ya se alineó con la silueta guía (ver
  /// positioning_alignment.dart).
  Size? lastCanvasSize;

  bool _isRecording = false;
  int _frameIndex = 0;
  // "Video limpio" ya no se ofrece al paciente (ver RecordingMode) — se
  // graba siempre con el esqueleto quemado encima, así se ve exactamente
  // lo mismo que en la app al revisar el video después.
  RecordingMode _mode = RecordingMode.overlayBurned;
  BodyView _view = BodyView.frontal;

  PoseFrame _latestPose = PoseFrame.empty;
  JointAngles _latestAngles = JointAngles.empty;
  JointAngularVelocity _latestVelocity = JointAngularVelocity.empty;

  // Historial corto del pico de velocidad (la articulación trackeada que se
  // mueve más rápido) por cuadro — se promedia para decidir `isMovingTooFast`
  // sin que el ruido de un solo cuadro lo prenda/apague de golpe (ver
  // kVelocitySmoothingWindow).
  final List<double> _recentPeakVelocities = [];
  bool _isMovingTooFast = false;

  // Estado para calcular velocidad angular frame a frame. Es continuo/en
  // vivo (no se resetea al empezar/terminar una grabación, ver
  // beginRecordingSession).
  JointAngles? _previousAngles;
  DateTime? _previousFrameTime;

  // Contadores de diagnóstico (ver DiagnosticsOverlay) — no se usan en la
  // lógica de medición, solo para distinguir en pantalla "el detector nunca
  // procesa un frame" (problema de formato/excepción) de "procesa pero
  // nunca encuentra una persona" (problema de rotación/encuadre).
  int _framesProcessed = 0;
  int _framesWithPose = 0;

  PoseFrame get latestPose => _latestPose;
  JointAngles get latestAngles => _latestAngles;
  JointAngularVelocity get latestVelocity => _latestVelocity;

  /// Si el promedio reciente de velocidad angular de la articulación
  /// trackeada más rápida supera [kFastMovementThresholdDegPerSec] — ver
  /// MeasureScreen, que muestra un aviso mientras esto sea `true` y se esté
  /// grabando. Se actualiza en cada cuadro junto con el resto del estado en
  /// vivo (ver [handleCameraImage]).
  bool get isMovingTooFast => _isMovingTooFast;

  bool get isRecording => _isRecording;
  RecordingMode get mode => _mode;
  BodyView get view => _view;
  int get rotationUsed => cameraFrameRotation(
    sensorOrientation: sensorOrientation,
    isFrontFacing: isFrontFacing,
  );
  int get framesProcessed => _framesProcessed;
  int get framesWithPose => _framesWithPose;
  String? get lastPoseError => _poseService.lastError;

  /// Sin UI que lo llame hoy (ver comentario en `_mode`) — queda disponible
  /// solo por si hace falta cambiarlo programáticamente más adelante.
  set mode(RecordingMode newMode) {
    if (_isRecording || newMode == _mode) return;
    _mode = newMode;
    notifyListeners();
  }

  /// Igual que [mode]: no se puede cambiar mientras hay una grabación en
  /// curso — la UI (BodyViewToggle) debe deshabilitarse en ese caso.
  set view(BodyView newView) {
    if (_isRecording || newView == _view) return;
    _view = newView;
    notifyListeners();
  }

  Future<void> initializePoseDetector() => _poseService.initialize();

  /// Callback para `startImageStream`/`startVideoRecording(onAvailable:)`.
  void handleCameraImage(CameraImage image) {
    if (_busyProcessing) return;
    _busyProcessing = true;

    _poseService
        .processCameraImage(
          image,
          sensorOrientation: sensorOrientation,
          isFrontFacing: isFrontFacing,
        )
        .then((frame) {
          if (frame == null) return;
          _framesProcessed++;
          if (frame.hasPose) _framesWithPose++;
          _latestPose = frame;
          _latestAngles = JointAngles.fromPoseFrame(frame)
              .filterForView(_view)
              .filterForRegion(region)
              .filterForJoints(trackedJoints);

          final now = DateTime.now();
          final previousAngles = _previousAngles;
          final previousFrameTime = _previousFrameTime;
          _latestVelocity = (previousAngles == null || previousFrameTime == null)
              ? JointAngularVelocity.empty
              : computeAngularVelocity(
                  previous: previousAngles,
                  current: _latestAngles,
                  dtMs: now.difference(previousFrameTime).inMilliseconds,
                );
          _previousAngles = _latestAngles;
          _previousFrameTime = now;

          final peaks = _latestVelocity.asOrderedList.whereType<double>().map((v) => v.abs());
          final peak = peaks.isEmpty ? 0.0 : peaks.reduce((a, b) => a > b ? a : b);
          _recentPeakVelocities.add(peak);
          if (_recentPeakVelocities.length > kVelocitySmoothingWindow) {
            _recentPeakVelocities.removeAt(0);
          }
          final smoothedPeak =
              _recentPeakVelocities.reduce((a, b) => a + b) / _recentPeakVelocities.length;
          _isMovingTooFast = smoothedPeak > kFastMovementThresholdDegPerSec;

          if (_isRecording) {
            _buffer.add(
              AngleSample(
                timestampMs: _recordingStopwatch.elapsedMilliseconds,
                frameIndex: _frameIndex++,
                angles: _latestAngles,
                velocity: _latestVelocity,
              ),
            );
          }
          notifyListeners();
        })
        .whenComplete(() {
          _busyProcessing = false;
        });
  }

  /// Limpia el buffer y arranca el cronómetro de la sesión. Debe llamarse
  /// justo antes de iniciar la grabación nativa/del overlay (ver
  /// CleanVideoRecorder / OverlayVideoRecorder), no después.
  ///
  /// No resetea `_previousAngles`/`_previousFrameTime`: la velocidad angular
  /// es una cantidad continua "en vivo", independiente de si hay una
  /// grabación en curso.
  void beginRecordingSession() {
    _buffer.clear();
    _frameIndex = 0;
    _recordingStopwatch
      ..reset()
      ..start();
    _isRecording = true;
    notifyListeners();
  }

  /// Detiene el cronómetro y devuelve todas las muestras acumuladas.
  List<AngleSample> endRecordingSession() {
    _isRecording = false;
    _recordingStopwatch.stop();
    notifyListeners();
    return _buffer.samples;
  }

  @override
  void dispose() {
    _poseService.dispose();
    super.dispose();
  }
}
