import '../core/pose/body_view.dart';

/// Un ejercicio del catálogo: nombre, video de demostración (empaquetado
/// como asset de la app) y la vista de cámara con la que debe medirse.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.videoAssetPath,
    required this.view,
  });

  final String id;
  final String name;
  final String videoAssetPath;
  final BodyView view;
}
