/// No hay cámara disponible, o no pudo inicializarse.
class CameraUnavailableException implements Exception {
  const CameraUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// El detector de pose no pudo inicializarse o falló de forma no recuperable.
class PoseDetectorInitException implements Exception {
  const PoseDetectorInitException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Falló la exportación de una sesión (CSV, .xlsx o video).
class ExportException implements Exception {
  const ExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
