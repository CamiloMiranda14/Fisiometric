/// Modo de grabación de video, elegido por el usuario antes de grabar.
enum RecordingMode {
  /// Video nativo sin overlay; los ángulos quedan en un archivo aparte.
  clean,

  /// El esqueleto y los ángulos quedan quemados en los píxeles del video.
  overlayBurned,
}
