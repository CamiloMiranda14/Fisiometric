import 'package:flutter/material.dart';

import '../../core/pose/body_view.dart';
import '../../theme/app_colors.dart';
import 'exercise_catalog.dart';
import 'exercise_demo_screen.dart';

/// Lista de ejercicios disponibles — todos son fijos, empaquetados como
/// asset por el equipo (el paciente no sube sus propios videos). Al elegir
/// uno se muestra su video de demostración (ExerciseDemoScreen) antes de
/// pasar a medir; tanto la vista de cámara de los sagitales como qué video
/// (izquierdo/derecho) se muestra se ajustan al lado que el paciente
/// indicó en PatientGateScreen, igual que en la sección "Tus ejercicios"
/// de HomeScreen — [affectedSide] cae a `derecha` cuando se llega hasta
/// acá sin ese contexto (p.ej. el atajo "Ejercicios" dentro de la propia
/// pantalla de medición).
class ExerciseCatalogScreen extends StatelessWidget {
  const ExerciseCatalogScreen({
    super.key,
    required this.patientName,
    this.affectedSide = BodyView.derecha,
  });

  final String patientName;
  final BodyView affectedSide;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar ejercicio')),
      body: ListView.separated(
        itemCount: exerciseCatalog.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final exercise = exerciseCatalog[index].forPatientSide(affectedSide);
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.tealPrimary,
              child: Icon(Icons.fitness_center_outlined, color: Colors.white),
            ),
            title: Text(exercise.name),
            subtitle: Text(exercise.view.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExerciseDemoScreen(
                  exercise: exercise,
                  videoAssetPath: exercise.videoAssetPathFor(affectedSide),
                  patientName: patientName,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
