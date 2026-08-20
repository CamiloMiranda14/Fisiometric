/// Grados a rotar el frame de cámara antes de pasarlo al detector de pose.
///
/// Con la app bloqueada a portrait (ver `main.dart`), el ángulo correcto
/// resulta ser directamente `sensorOrientation`, igual para cámara trasera
/// y frontal — confirmado en dispositivo (Moto G47): la corrección "cámara
/// frontal en sentido contrario" que suelen usar los ejemplos de ML Kit
/// (pensada para compensar rotación *variable* del dispositivo, no fija a
/// portrait) dejó el esqueleto exactamente 180° invertido con la frontal
/// (sensor 270° → esa fórmula daba 90°; el valor correcto era 270°, el
/// propio `sensorOrientation` sin ajustar). [isFrontFacing] se conserva en
/// la firma por si aparece un problema de espejo (izquierda/derecha
/// invertidos) a resolver aparte — no afecta la rotación en sí.
int cameraFrameRotation({
  required int sensorOrientation,
  required bool isFrontFacing,
}) {
  return sensorOrientation;
}
