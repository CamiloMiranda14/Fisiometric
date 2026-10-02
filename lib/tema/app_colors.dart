import 'package:flutter/material.dart';

/// Paleta extraída del logo de Fisiometric (logofisiometric.png).
abstract final class AppColors {
  /// Teal/petróleo oscuro de la figura humana y el anillo del logo.
  static const Color tealPrimary = Color(0xFF0E4C54);
  static const Color tealDark = Color(0xFF0A363C);
  static const Color tealLight = Color(0xFF186060);

  /// Naranja del transportador, el pulso y el texto "METRIC".
  static const Color orangeAccent = Color(0xFFE06A0A);
  static const Color orangeDark = Color(0xFFB85608);

  /// Gris oscuro del texto "FISIO".
  static const Color darkGrey = Color(0xFF3C3C3C);

  /// Umbral de confianza de un landmark bajo el cual se considera "no visible".
  static const Color lowConfidence = Color(0xFFBDBDBD);

  static const Color success = Color(0xFF2E7D32);

  /// Verde más claro que [success] — fondo de una tarjeta de ejercicio ya
  /// realizado (ver HomeScreen._TodaysMeasurementCard), donde el teal
  /// normal de "pendiente" no aplica pero tampoco conviene el verde oscuro
  /// de alerta/éxito puntual.
  static const Color successLight = Color(0xFF66BB6A);
  static const Color danger = Color(0xFFC62828);

  /// Amarillo/ámbar — banda intermedia entre `orangeAccent` y `success` en
  /// los medidores de "qué tan cerca del objetivo" (ver ProgressScreen).
  static const Color warning = Color(0xFFF9A825);
}
