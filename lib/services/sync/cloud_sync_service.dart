import 'dart:io';

import '../../models/session_metadata.dart';
import '../patient/patient_profile_service.dart';

/// Punto único de enganche para sincronizar datos con la nube — pensado
/// para Firebase (Firestore para los datos estructurados, Storage para
/// video/CSV), todavía sin implementar porque no existe el proyecto de
/// Firebase ni sus credenciales. Mientras tanto, [instance] apunta a
/// [NoopCloudSyncService] (no hace nada) para que el resto de la app
/// funcione exactamente igual que hoy.
///
/// MeasureScreen y PatientProfileService ya llaman a este servicio en el
/// momento correcto (justo después de guardar localmente) — cuando exista
/// el proyecto de Firebase, el trabajo es: escribir una implementación real
/// de esta clase (`FirebaseCloudSyncService`, usando `cloud_firestore` +
/// `firebase_storage` + `firebase_auth`) y cambiar la línea de [instance]
/// para que apunte a ella. Ningún otro archivo necesita tocarse.
///
/// ESQUEMA PLANEADO:
/// - Auth: anónima (`firebase_auth`, `signInAnonymously()`) — el paciente
///   nunca ve una pantalla de login. La cédula sigue siendo la clave real
///   del dato (como ya lo es localmente); Firebase Auth solo identifica
///   "esta instancia de la app" ante las reglas de seguridad de Firestore
///   /Storage (que deben exigir `request.auth != null`, sin login real).
/// - Firestore:
///   - `patients/{cedula}` → los mismos campos que [PatientProfile]
///     (name, age, pathology, affectedSide, reminderHour, reminderMinute,
///     notificationsEnabled).
///   - `patients/{cedula}/sessions/{sessionId}` → el mismo JSON que ya se
///     escribe en `session.json` (ver `SessionMetadata.toJson()`).
/// - Storage:
///   - `patients/{cedula}/sessions/{sessionId}/video.mp4`
///   - `patients/{cedula}/sessions/{sessionId}/datos.csv`
/// - El archivo local sigue siendo la fuente de verdad para lo recién
///   grabado (nada de esto cambia cómo funciona hoy) — la nube es un
///   respaldo de lo mismo, no un reemplazo. `cloud_firestore` ya trae
///   persistencia y reintento automático offline "de fábrica" para los
///   documentos; solo la subida de video a Storage necesitaría un
///   reintento propio (por ejemplo, al reabrir la app) si falla por falta
///   de conexión en el momento de grabar.
abstract class CloudSyncService {
  static CloudSyncService instance = NoopCloudSyncService();

  /// Sube/actualiza el perfil de [profile] en `patients/{cedula}`.
  Future<void> uploadProfile(PatientProfile profile);

  /// Sube `session.json` (Firestore) y el video/CSV de [dir] (Storage) bajo
  /// `patients/{cedula}/sessions/{metadata.id}`.
  Future<void> uploadSession(Directory dir, SessionMetadata metadata);
}

class NoopCloudSyncService implements CloudSyncService {
  @override
  Future<void> uploadProfile(PatientProfile profile) async {}

  @override
  Future<void> uploadSession(Directory dir, SessionMetadata metadata) async {}
}
