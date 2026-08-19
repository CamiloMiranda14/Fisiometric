import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../../core/pose/angular_velocity_calculator.dart';
import '../../../core/pose/body_view.dart';
import '../../../core/pose/symmetry_calculator.dart';
import '../../../models/angle_sample.dart';
import '../../../models/bilateral_symmetry.dart';
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
  int _sensorOrientation = 0;
  bool _isRecording = false;
  int _frameIndex = 0;
  RecordingMode _mode = RecordingMode.clean;
  BodyView _view = BodyView.frontal;

  PoseFrame _latestPose = PoseFrame.empty;
  JointAngles _latestAngles = JointAngles.empty;
  JointAngularVelocity _latestVelocity = JointAngularVelocity.empty;
  BilateralSymmetry _latestSymmetry = BilateralSymmetry.empty;

  // Estado para calcular velocidad angular frame a frame. Es continuo/en
  // vivo (no se resetea al empezar/terminar una grabación, ver
  // beginRecordingSession).
  JointAngles? _previousAngles;
  DateTime? _previousFrameTime;

  PoseFrame get latestPose => _latestPose;
  JointAngles get latestAngles => _latestAngles;
  JointAngularVelocity get latestVelocity => _latestVelocity;
  BilateralSymmetry get latestSymmetry => _latestSymmetry;
  bool get isRecording => _isRecording;
  RecordingMode get mode => _mode;
  BodyView get view => _view;

  /// El modo no se puede cambiar mientras hay una grabación en curso — la
  /// UI (RecordingModeToggle) debe deshabilitarse en ese caso.
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

  /// Ángulo (0/90/180/270) que el detector debe aplicar para enderezar la
  /// imagen del sensor — se fija una vez, al iniciar la cámara (ver
  /// CameraDescription.sensorOrientation), y no cambia mientras la app está
  /// bloqueada a portrait.
  set sensorOrientation(int degrees) => _sensorOrientation = degrees;

  /// Callback para `startImageStream`/`startVideoRecording(onAvailable:)`.
  void handleCameraImage(CameraImage image) {
    if (_busyProcessing) return;
    _busyProcessing = true;

    _poseService
        .processCameraImage(image, sensorOrientation: _sensorOrientation)
        .then((frame) {
          if (frame == null) return;
          _latestPose = frame;
          _latestAngles = JointAngles.fromPoseFrame(frame).filterForView(_view);

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

          _latestSymmetry = _view == BodyView.frontal
              ? computeBilateralSymmetry(_latestAngles)
              : BilateralSymmetry.empty;

          if (_isRecording) {
            _buffer.add(
              AngleSample(
                timestampMs: _recordingStopwatch.elapsedMilliseconds,
                frameIndex: _frameIndex++,
                angles: _latestAngles,
                velocity: _latestVelocity,
                symmetry: _latestSymmetry,
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
