import 'dart:convert';
import 'dart:io';

import '../../models/session_metadata.dart';
import 'session_storage_service.dart';

/// Una sesión guardada ya leída (carpeta + metadatos) — evita releer y
/// reparsear `session.json` en cada pantalla que necesita la lista
/// completa (SessionsListScreen, ProgressScreen).
class SavedSession {
  const SavedSession({required this.dir, required this.metadata});

  final Directory dir;
  final SessionMetadata metadata;
}

/// Carga todas las sesiones guardadas, más reciente primero — omite
/// silenciosamente cualquier `session.json` corrupto o incompleto (p.ej.
/// la app se cerró a mitad de guardar) en vez de romper toda la lista.
Future<List<SavedSession>> loadAllSessions(SessionStorageService storage) async {
  final dirs = await storage.listSessionDirectories();
  final entries = <SavedSession>[];
  for (final dir in dirs) {
    final jsonFile = File('${dir.path}/session.json');
    if (!await jsonFile.exists()) continue;
    try {
      final raw = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
      entries.add(SavedSession(dir: dir, metadata: SessionMetadata.fromJson(raw)));
    } catch (_) {
      continue;
    }
  }
  return entries;
}
