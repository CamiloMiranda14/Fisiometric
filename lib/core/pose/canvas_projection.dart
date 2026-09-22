import 'dart:ui';

/// Convierte un punto (x, y) en espacio de imagen (según [imageWidth]/
/// [imageHeight]) a espacio de lienzo, aplicando el mismo espejo horizontal
/// que la cámara frontal en vivo (ver SkeletonPainter) cuando
/// [isFrontFacing] es cierto. Se aísla aquí (en vez de vivir solo dentro de
/// SkeletonPainter) para que cualquier otra comparación entre un landmark
/// real y un punto de referencia dibujado en el lienzo — como la silueta
/// guía, ver positioning_alignment.dart — use exactamente el mismo sistema
/// de coordenadas que lo que se ve en pantalla.
Offset imageToCanvas({
  required double x,
  required double y,
  required int imageWidth,
  required int imageHeight,
  required Size canvasSize,
  required bool isFrontFacing,
}) {
  final scaleX = canvasSize.width / imageWidth;
  final scaleY = canvasSize.height / imageHeight;
  final canvasX = isFrontFacing
      ? canvasSize.width - (x * scaleX)
      : x * scaleX;
  return Offset(canvasX, y * scaleY);
}
