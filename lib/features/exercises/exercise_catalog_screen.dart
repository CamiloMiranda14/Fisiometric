import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'exercise_catalog.dart';
import 'exercise_demo_screen.dart';

/// Lista de ejercicios disponibles — al elegir uno se muestra su video de
/// demostración (ExerciseDemoScreen) antes de pasar a medir.
class ExerciseCatalogScreen extends StatelessWidget {
  const ExerciseCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar ejercicio')),
      body: ListView.separated(
        itemCount: exerciseCatalog.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final exercise = exerciseCatalog[index];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.tealPrimary,
              child: Icon(Icons.fitness_center_outlined, color: Colors.white),
            ),
            title: Text(exercise.name),
            subtitle: Text(exercise.view.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ExerciseDemoScreen(exercise: exercise)),
            ),
          );
        },
      ),
    );
  }
}
