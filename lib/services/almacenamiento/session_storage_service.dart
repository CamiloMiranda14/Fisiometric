import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Crea y administra las carpetas de sesión bajo el directorio privado de
/// documentos de la app: `<AppDocuments>/sesiones/<id>/`. Al ser privado a
/// la app, no requiere ningún permiso de almacenamiento en Android 10+.
class SessionStorageService {
  static const String sessionsDirName = 'sesiones';

  Future<Directory> sessionsRootDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/$sessionsDirName');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> createSessionDirectory(String sessionId) async {
    final root = await sessionsRootDirectory();
    final dir = Directory('${root.path}/$sessionId');
    await dir.create(recursive: true);
    return dir;
  }

  /// Carpetas de sesión existentes, más reciente primero (el id es el
  /// timestamp de inicio, así que ordenar por nombre alcanza).
  Future<List<Directory>> listSessionDirectories() async {
    final root = await sessionsRootDirectory();
    final entries = await root.list().toList();
    final dirs = entries.whereType<Directory>().toList();
    dirs.sort((a, b) => b.path.compareTo(a.path));
    return dirs;
  }

  Future<void> deleteSession(Directory dir) async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Borra todas las sesiones guardadas (pruebas, grabaciones, etc.) — para
  /// limpiar de una vez las pruebas acumuladas durante el desarrollo/uso de
  /// la app, sin tener que eliminar sesión por sesión.
  Future<void> deleteAllSessions() async {
    final root = await sessionsRootDirectory();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    await root.create(recursive: true);
  }
}
