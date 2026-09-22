import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// Altura (fracción 0-1 de la imagen) de la línea de cintura/entrepierna en
/// `assets/guide/frontal_outline.png` y `assets/guide/lateral_outline.png`
/// — límite usado para recortar la silueta guía por región (ver
/// PositioningGuidePainter). Medida directamente sobre esas 2 imágenes
/// (ambas recortadas con el mismo padding vertical desde la misma foto
/// fuente, así que comparten esta fracción).
const double kOutlineWaistFraction = 0.51;

/// Las 2 siluetas de referencia (frontal y lateral, mirando hacia la
/// izquierda por convención — ver PositioningGuidePainter para el volteo
/// en `BodyView.izquierda`), ya decodificadas — se cargan una sola vez al
/// iniciar MeasureScreen y se reusan en cada repintado.
class BodyOutlineImages {
  const BodyOutlineImages({required this.frontal, required this.lateral});

  final ui.Image frontal;
  final ui.Image lateral;
}

Future<ui.Image> _loadAsset(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  return frame.image;
}

Future<BodyOutlineImages> loadBodyOutlineImages() async {
  final results = await Future.wait([
    _loadAsset('assets/guide/frontal_outline.png'),
    _loadAsset('assets/guide/lateral_outline.png'),
  ]);
  return BodyOutlineImages(frontal: results[0], lateral: results[1]);
}
