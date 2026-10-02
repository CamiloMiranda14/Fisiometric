import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../paciente/patient_profile_service.dart';

/// Directorio de TODOS los pacientes que han usado este teléfono, para que
/// el fisioterapeuta pueda elegir uno y ver su progreso o asignarle
/// ejercicios recomendados (ver TherapistDashboardScreen).
///
/// A diferencia de `PatientProfileService` (que solo recuerda el ÚLTIMO
/// perfil, como comodidad para prellenar PatientGateScreen), este guarda
/// uno por cédula — [PatientProfileService.save] ya llama a [upsert] en
/// cada guardado, así que cualquier paciente que pase por el formulario de
/// inicio (o edite sus datos en Configuración) queda acá automáticamente,
/// sin que el fisioterapeuta tenga que agregarlo a mano. El fisio igual
/// puede agregar un paciente nuevo directo desde su panel (ver
/// TherapistDashboardScreen._addPatient), que también pasa por [upsert].
class PatientRosterService {
  const PatientRosterService();

  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/patients_roster.json');
  }

  Future<Map<String, PatientProfile>> _readAll() async {
    final file = await _file();
    if (!await file.exists()) return {};
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return {};
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final result = <String, PatientProfile>{};
    for (final entry in data.entries) {
      final profile = PatientProfile.fromJson(
        entry.value as Map<String, dynamic>,
      );
      if (profile != null) result[entry.key] = profile;
    }
    return result;
  }

  Future<void> _writeAll(Map<String, PatientProfile> all) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  /// Todos los pacientes conocidos, ordenados por nombre.
  Future<List<PatientProfile>> loadAll() async {
    final all = await _readAll();
    final list = all.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<PatientProfile?> loadByCedula(String cedula) async {
    final all = await _readAll();
    return all[cedula];
  }

  /// Agrega o reemplaza el registro de este paciente (clave = cédula).
  Future<void> upsert(PatientProfile profile) async {
    if (profile.cedula.trim().isEmpty) return;
    final all = await _readAll();
    all[profile.cedula] = profile;
    await _writeAll(all);
  }
}
