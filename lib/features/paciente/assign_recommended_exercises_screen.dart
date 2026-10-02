import 'package:flutter/material.dart';

import '../../services/paciente/patient_profile_service.dart';
import '../../services/paciente/patient_roster_service.dart';
import '../../tema/app_colors.dart';
import '../ejercicios/recommended_exercise_catalog.dart';

/// El fisioterapeuta elige, a mano, cuáles de los ejercicios terapéuticos
/// (los que no se graban ni se evalúan, ver RecommendedExerciseCatalogScreen)
/// le corresponden a [profile] — reemplaza del todo la selección automática
/// por patología (ver `PatientProfile.recommendedExerciseIds`).
///
/// Guarda en PatientRosterService (el directorio del fisio) y, si esta
/// misma cédula resulta ser también "el último perfil" del teléfono (ver
/// PatientProfileService), lo actualiza ahí también — si no, el paciente
/// seguiría viendo la asignación vieja en su propio HomeScreen hasta que
/// alguien vuelva a guardar ese perfil por otro lado.
class AssignRecommendedExercisesScreen extends StatefulWidget {
  const AssignRecommendedExercisesScreen({super.key, required this.profile});

  final PatientProfile profile;

  @override
  State<AssignRecommendedExercisesScreen> createState() =>
      _AssignRecommendedExercisesScreenState();
}

class _AssignRecommendedExercisesScreenState
    extends State<AssignRecommendedExercisesScreen> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.profile.recommendedExerciseIds};
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.profile.copyWith(
      assignedRecommendedExerciseIds: _selected,
    );
    await const PatientRosterService().upsert(updated);

    // Si esta cédula es también el perfil activo del teléfono (el paciente
    // se mide él mismo acá), se actualiza ese archivo también.
    const profileService = PatientProfileService();
    final last = await profileService.loadLast();
    if (last != null && last.cedula == updated.cedula) {
      await profileService.save(updated);
    }

    if (mounted) Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Asignar a ${widget.profile.name}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Por defecto se asignan solo con la patología del paciente. '
              'Marca a mano los que quieras que le aparezcan en vez de eso.',
              style: TextStyle(
                color: AppColors.darkGrey.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
          for (final exercise in recommendedExerciseCatalog)
            CheckboxListTile(
              value: _selected.contains(exercise.id),
              title: Text(exercise.name),
              onChanged: (checked) => setState(() {
                if (checked ?? false) {
                  _selected.add(exercise.id);
                } else {
                  _selected.remove(exercise.id);
                }
              }),
            ),
        ],
      ),
    );
  }
}
