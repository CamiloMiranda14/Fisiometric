import 'package:camera/camera.dart';

import '../../models/pose_frame.dart';

/// Límite de aislamiento del motor de detección de pose.
///
/// Ningún tipo del paquete `flutter_pose_detection` debe cruzar esta
/// interfaz — solo `MediaPipePoseDetectionService` lo importa. Si ese
/// paquete resulta poco confiable, cambiar de motor (p.ej. a
/// google_mlkit_pose_detection) implica reescribir un solo archivo.
abstract class PoseDetectionService {
  /// Carga el modelo. Debe llamarse una vez antes de [processCameraImage].
  ///
  /// Lanza [PoseDetectorInitException] (ver core/errors) si falla.
  Future<void> initialize();

  /// Procesa un frame de cámara y devuelve el resultado.
  ///
  /// Devuelve [PoseFrame.empty] si el modelo corrió pero no detectó ninguna
  /// persona, y `null` si el frame no pudo procesarse (se descarta en
  /// silencio — un fallo puntual no debe interrumpir el flujo en vivo).
  ///
  /// [isFrontFacing] no afecta la rotación (con la app bloqueada a
  /// portrait, [sensorOrientation] solo ya es correcto para ambas cámaras —
  /// confirmado en dispositivo) ni las etiquetas izquierda/derecha (ya
  /// vienen bien de MediaPipe) — el único ajuste que sí necesita la cámara
  /// frontal es puramente visual, en `SkeletonPainter`. Se conserva el
  /// parámetro aquí solo por si hiciera falta a futuro.
  Future<PoseFrame?> processCameraImage(
    CameraImage image, {
    required int sensorOrientation,
    required bool isFrontFacing,
  });

  /// Mensaje de la última excepción descartada por [processCameraImage], o
  /// `null` si el frame más reciente se procesó sin error. Solo para
  /// diagnóstico en pantalla (ver DiagnosticsOverlay) — no afecta el flujo
  /// en vivo, que ya descarta frames fallidos en silencio a propósito.
  String? get lastError;

  Future<void> dispose();
}
