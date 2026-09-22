import 'package:flutter/material.dart';

import '../../../core/pose/body_outline_images.dart';
import '../../../core/pose/body_region.dart';
import '../../../core/pose/body_view.dart';
import '../../../core/pose/positioning_guide_targets.dart';
import '../../../theme/app_colors.dart';

/// Dibuja una silueta fantasma (posiciones fijas — no depende de detección
/// alguna) para que el paciente se ubique a la distancia y postura
/// correctas de la cámara antes de empezar a grabar.
///
/// Usa las 2 imágenes de referencia reales (frontal/lateral, ver
/// body_outline_images.dart) en vez de un contorno calculado a mano —
/// varios intentos de trazarlo por coordenadas (huesos, cápsulas, un path
/// de líneas) siempre terminaban viéndose deforme en algún punto (axila,
/// cintura, piernas). `BlendMode.srcIn` recolorea toda la imagen (blanco o
/// verde, según [isAligned]) usando su alfa como máscara — el color
/// original de la línea de la imagen no importa.
///
/// Para `region == upperBody` se encaja la imagen COMPLETA y se encoge a
/// [kUpperBodyGuideScale] (la silueta es una guía de distancia — un poco
/// más chica que "llena el lienzo" deja margen a propósito: si el paciente
/// levanta o extiende el brazo durante el ejercicio, ese brazo real tiene
/// espacio de sobra para seguir dentro de cuadro), y esa versión encogida
/// se desplaza verticalmente para que la franja cabeza-cintura (ver
/// kOutlineWaistFraction) quede centrada en el lienzo — la cámara para
/// estos ejercicios se ubica a la altura del hombro/codo, no de cuerpo
/// completo, así que esa franja no debe quedar pegada arriba con el resto
/// del lienzo vacío abajo. Se recorta lo que quede por debajo de esa franja
/// (cintura hacia abajo) después de desplazar.
///
/// IMPORTANTE: `positioning_guide_targets.dart` calcula, a partir de
/// [kUpperBodyGuideScale] y `kOutlineWaistFraction`, dónde cae cada
/// landmark objetivo tras esta MISMA escala+desplazamiento — si se cambia
/// cualquiera de las dos constantes o el orden de las operaciones acá, hay
/// que revisar que ese archivo siga calculando lo mismo, o la detección de
/// alineación queda desfasada de lo que se ve en pantalla (ya pasó una
/// vez).
///
/// `lowerBody` (cadera, rodilla) se deja **sin encoger, recortar ni
/// desplazar** — a diferencia de solo mostrar las piernas flotando sin
/// ninguna referencia del resto del cuerpo, ver el cuerpo completo da mejor
/// referencia para ubicarse a la distancia correcta, y al encajarse entera
/// ya queda centrada por construcción.
class PositioningGuidePainter extends CustomPainter {
  const PositioningGuidePainter({
    required this.view,
    required this.isAligned,
    required this.region,
    required this.images,
  });

  final BodyView view;

  /// Si el paciente ya está alineado — cambia el color de la guía de blanco
  /// (esperando) a verde (lista para la cuenta regresiva), dando
  /// retroalimentación inmediata sin depender solo del texto.
  final bool isAligned;

  /// Qué parte del cuerpo dibujar — ver BodyRegion.
  final BodyRegion region;

  final BodyOutlineImages images;

  @override
  void paint(Canvas canvas, Size size) {
    final image = view == BodyView.frontal ? images.frontal : images.lateral;
    // La imagen base (lateral_outline.png) mira hacia la izquierda — se usa
    // tal cual para "derecha" y se espeja para "izquierda" (confirmado en
    // dispositivo: al revés se veía mirando para el lado equivocado).
    final flip = view == BodyView.izquierda;

    final color = isAligned ? AppColors.success : Colors.white;
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(
        color.withValues(alpha: 0.85),
        BlendMode.srcIn,
      )
      ..filterQuality = FilterQuality.medium;

    // La silueta nunca se agranda más allá de encajar el cuerpo entero —
    // solo cambia, para tren superior, la escala (más chica, deja margen
    // para un brazo levantado/extendido) y en qué parte del lienzo queda
    // esa imagen ya encajada (ver comentario de clase).
    final fullImageSize = Size(image.width.toDouble(), image.height.toDouble());
    final srcRect = Offset.zero & fullImageSize;

    final fitted = applyBoxFit(BoxFit.contain, fullImageSize, size);
    var dstSize = fitted.destination;
    if (region == BodyRegion.upperBody) {
      dstSize = dstSize * kUpperBodyGuideScale;
    }
    var dstRect = Rect.fromLTWH(
      (size.width - dstSize.width) / 2,
      (size.height - dstSize.height) / 2,
      dstSize.width,
      dstSize.height,
    );

    double? clipBottom;
    if (region == BodyRegion.upperBody) {
      final bandHeight = kOutlineWaistFraction * dstSize.height;
      // Desplaza verticalmente el rectángulo (misma escala, mismo ancho)
      // para que la franja cabeza-cintura quede centrada en el lienzo.
      final bandMidNow = dstRect.top + bandHeight / 2;
      final shift = size.height / 2 - bandMidNow;
      dstRect = dstRect.shift(Offset(0, shift));
      clipBottom = dstRect.top + bandHeight;
    }

    canvas.save();
    if (flip) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    if (clipBottom != null) {
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, clipBottom));
    }

    canvas.drawImageRect(image, srcRect, dstRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PositioningGuidePainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.isAligned != isAligned ||
      oldDelegate.region != region ||
      oldDelegate.images != images;
}
