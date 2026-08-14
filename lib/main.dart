import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La app se bloquea a portrait: simplifica la rotación del sensor de cámara,
  // el tamaño de captura del overlay y la alineación del esqueleto (ver plan).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const FisiometricApp());
}
