import 'package:flutter/material.dart';

import '../../services/patient/patient_profile_service.dart';
import '../../theme/app_colors.dart';
import 'recommended_exercise_catalog.dart';
import 'recommended_exercise_screen.dart';

/// Catálogo de ejercicios terapéuticos recomendados — a diferencia de
/// "Medición del día de hoy" (que registra el rango de movimiento con la
/// cámara), estos son videos de referencia para que el paciente los repita
/// por su cuenta; no se graban ni se evalúan. Los que corresponden a la
/// patología del paciente (ver Pathology.recommendedExerciseIds) aparecen
/// marcados como recomendados, arriba del resto.
class RecommendedExerciseCatalogScreen extends StatelessWidget {
  const RecommendedExerciseCatalogScreen({super.key, required this.patientProfile});

  final PatientProfile patientProfile;

  @override
  Widget build(BuildContext context) {
    final recommendedIds = patientProfile.pathology.recommendedExerciseIds.toSet();
    final ordered = [
      ...recommendedExerciseCatalog.where((e) => recommendedIds.contains(e.id)),
      ...recommendedExerciseCatalog.where((e) => !recommendedIds.contains(e.id)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ejercicios recomendados')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: ordered.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final exercise = ordered[index];
          final isForYou = recommendedIds.contains(exercise.id);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isForYou ? AppColors.tealPrimary : AppColors.darkGrey,
              child: const Icon(Icons.self_improvement_outlined, color: Colors.white),
            ),
            title: Text(exercise.name),
            subtitle: isForYou
                ? const Text(
                    'Recomendado para tu patología',
                    style: TextStyle(color: AppColors.tealPrimary),
                  )
                : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecommendedExerciseScreen(
                  exercise: exercise,
                  patientProfile: patientProfile,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
