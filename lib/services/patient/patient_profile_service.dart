import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/pose/body_view.dart';
import '../../models/pathology.dart';

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
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final name = data['name'] as String?;
    final age = data['age'] as int?;
    final pathologyName = data['pathology'] as String?;
    final sideName = data['affectedSide'] as String?;
    if (name == null || age == null || pathologyName == null || sideName == null) {
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
    );
  }

  Future<void> save(PatientProfile profile) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode({
        'cedula': profile.cedula,
        'name': profile.name,
        'age': profile.age,
        'pathology': profile.pathology.name,
        'affectedSide': profile.affectedSide.name,
      }),
    );
  }
}
