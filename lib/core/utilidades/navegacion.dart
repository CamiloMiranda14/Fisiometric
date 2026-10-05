import 'package:flutter/material.dart';

/// Navega a [pantalla] y devuelve lo que deje `Navigator.pop` — para no
/// repetir `Navigator.of(context).push(MaterialPageRoute(...))` en cada
/// botón de cada pantalla.
extension NavegacionExtension on BuildContext {
  Future<T?> ir<T>(Widget pantalla) {
    return Navigator.of(
      this,
    ).push<T>(MaterialPageRoute(builder: (_) => pantalla));
  }
}
