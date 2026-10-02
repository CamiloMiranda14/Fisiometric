import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/notificaciones/daily_reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La app se bloquea a portrait: simplifica la rotación del sensor de cámara,
  // el tamaño de captura del overlay y la alineación del esqueleto (ver plan).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // Registra el manejador de toques de notificaciones ("Abrir app"/
  // "Posponer") lo antes posible — si la app se abre justo por haber
  // tocado la notificación, este registro tiene que estar listo desde
  // antes de que se arme cualquier pantalla.
  await DailyReminderService().ensureInitialized();
  runApp(const FisiometricApp());
}
