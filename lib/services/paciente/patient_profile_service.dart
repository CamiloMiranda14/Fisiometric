import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/pose/body_view.dart';
import '../../modelos/pathology.dart';
import '../sincronizacion/cloud_sync_service.dart';
import '../paciente/patient_roster_service.dart';

/// Datos del paciente ingresados en PatientGateScreen al abrir la app —
/// nombre, edad, qué patología presenta (determina el/los ejercicio(s)
/// recomendados y la articulación que se sigue en "Mi progreso") y de qué
/// lado la presenta (determina si los ejercicios sagitales se miden en
/// `BodyView.izquierda` o `.derecha` — ver HomeScreen).
class PatientProfile {
  const PatientProfile({
    required this.cedula,
    required this.name,
    required this.age,
    required this.pathology,
    required this.affectedSide,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.notificationsEnabled = true,
    this.assignedRecommendedExerciseIds,
  });

  /// Número de cédula — identifica al paciente de forma inequívoca (el
  /// nombre solo no alcanza si hay dos pacientes con el mismo nombre).
  final String cedula;
  final String name;
  final int age;
  final Pathology pathology;

  /// Solo `izquierda`/`derecha` — nunca `frontal` (ver el selector en
  /// PatientGateScreen, que solo ofrece esas 2 opciones).
  final BodyView affectedSide;

  /// A qué hora del día quiere el paciente el recordatorio diario (ver
  /// DailyReminderService) — elegible la primera vez que abre la app,
  /// justo después de aceptar el permiso de notificaciones (ver
  /// PatientGateScreen), y cambiable después desde el menú de HomeScreen.
  /// 8:00 p.m. por defecto, para perfiles guardados antes de agregar esto.
  final int reminderHour;
  final int reminderMinute;

  /// Si está en `false`, DailyReminderService no programa ningún aviso
  /// (cancela los que hubiera pendientes) — el paciente lo desactiva desde
  /// SettingsScreen. `true` por defecto, también para perfiles guardados
  /// antes de agregar este interruptor.
  final bool notificationsEnabled;

  /// IDs de `recommendedExerciseCatalog` elegidos a mano por un
  /// fisioterapeuta (ver TherapistDashboardScreen) — si no es `null`,
  /// REEMPLAZA del todo a `pathology.recommendedExerciseIds` en
  /// HomeScreen/RecommendedExerciseCatalogScreen. `null` (el default) deja
  /// el comportamiento de siempre: los recomendados los decide solo la
  /// patología.
  final Set<String>? assignedRecommendedExerciseIds;

  /// Qué ejercicios recomendados le corresponden de verdad a este paciente
  /// — la asignación manual del fisio si existe, si no la de su patología.
  Set<String> get recommendedExerciseIds =>
      assignedRecommendedExerciseIds ??
      pathology.recommendedExerciseIds.toSet();

  PatientProfile copyWith({
    String? cedula,
    String? name,
    int? age,
    Pathology? pathology,
    BodyView? affectedSide,
    int? reminderHour,
    int? reminderMinute,
    bool? notificationsEnabled,
    Set<String>? assignedRecommendedExerciseIds,
  }) => PatientProfile(
    cedula: cedula ?? this.cedula,
    name: name ?? this.name,
    age: age ?? this.age,
    pathology: pathology ?? this.pathology,
    affectedSide: affectedSide ?? this.affectedSide,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    assignedRecommendedExerciseIds:
        assignedRecommendedExerciseIds ?? this.assignedRecommendedExerciseIds,
  );

  Map<String, dynamic> toJson() => {
    'cedula': cedula,
    'name': name,
    'age': age,
    'pathology': pathology.name,
    'affectedSide': affectedSide.name,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'notificationsEnabled': notificationsEnabled,
    if (assignedRecommendedExerciseIds != null)
      'assignedRecommendedExerciseIds': assignedRecommendedExerciseIds!
          .toList(),
  };

  /// `null` si faltan los campos mínimos (nombre/edad/patología/lado) — ver
  /// usos en [PatientProfileService.loadLast]/[PatientRosterService].
  static PatientProfile? fromJson(Map<String, dynamic> data) {
    final name = data['name'] as String?;
    final age = data['age'] as int?;
    final pathologyName = data['pathology'] as String?;
    final sideName = data['affectedSide'] as String?;
    if (name == null ||
        age == null ||
        pathologyName == null ||
        sideName == null) {
      return null;
    }
    return PatientProfile(
      // Perfiles guardados antes de agregar este campo no tienen esta
      // clave — se prellena vacío en vez de descartar todo el perfil.
      cedula: data['cedula'] as String? ?? '',
      name: name,
      age: age,
      pathology: Pathology.values.byName(pathologyName),
      affectedSide: BodyView.values.byName(sideName),
      // Perfiles guardados antes de agregar el recordatorio personalizable
      // no tienen estas claves — se asume 8:00 p.m. (el valor por defecto
      // de antes de que fuera elegible).
      reminderHour: data['reminderHour'] as int? ?? 20,
      reminderMinute: data['reminderMinute'] as int? ?? 0,
      // Perfiles guardados antes de agregar este interruptor no tienen esta
      // clave — se asume `true` (las notificaciones ya estaban activas).
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      assignedRecommendedExerciseIds:
          (data['assignedRecommendedExerciseIds'] as List<dynamic>?)
              ?.cast<String>()
              .toSet(),
    );
  }
}

/// Recuerda el último perfil ingresado — solo como comodidad para
/// prellenar PatientGateScreen (que igual se muestra y hay que
/// confirmar/editar cada vez que se abre la app, ver esa pantalla), no
/// como un perfil o login persistente.
class PatientProfileService {
  const PatientProfileService();

  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/patient_profile.json');
  }

  Future<PatientProfile?> loadLast() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return null;
    return PatientProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(PatientProfile profile) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(profile.toJson()));
    // No se espera — respaldo en la nube (ver CloudSyncService), sin
    // demorar a quien llama a save() por una subida que hoy ni siquiera
    // existe de verdad (NoopCloudSyncService).
    unawaited(CloudSyncService.instance.uploadProfile(profile));
    // Tampoco se espera — guarda/actualiza este paciente en el directorio
    // que ve el fisioterapeuta (ver PatientRosterService), además de
    // quedar como "el último" acá. Cualquiera que pase por este `save()`
    // (PatientGateScreen, SettingsScreen, el selector de hora) queda
    // registrado ahí automáticamente, no solo quien se agregue a mano
    // desde TherapistDashboardScreen.
    unawaited(const PatientRosterService().upsert(profile));
  }
}
