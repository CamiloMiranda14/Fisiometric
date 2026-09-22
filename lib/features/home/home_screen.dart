import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../services/patient/patient_profile_service.dart';
import '../../theme/app_colors.dart';
import '../exercises/exercise_catalog.dart';
import '../exercises/exercise_catalog_screen.dart';
import '../exercises/exercise_demo_screen.dart';
import '../exercises/recommended_exercise_catalog_screen.dart';
import '../progress/progress_screen.dart';
import '../sessions/sessions_list_screen.dart';
import 'quick_test_view_screen.dart';

/// Ítems que no son específicos de este paciente/patología — quedan detrás
/// del ícono de menú en vez de ocupar espacio en la pantalla principal,
/// para que esa pantalla quede especializada solo en lo que le toca a este
/// paciente (ver [HomeScreen]).
enum _MoreMenuItem { quickTest, fullCatalog, savedSessions }

/// Pantalla de inicio: saluda al paciente y lo guía directo hacia el/los
/// movimiento(s) de medición que le corresponden según la patología
/// elegida en PatientGateScreen (ver Pathology.exerciseIds) — "Medición
/// del día de hoy", la sección más destacada de la pantalla, ya que es lo
/// que se espera que haga cada vez que abre la app.
///
/// Aparte de eso están los ejercicios terapéuticos recomendados (que no se
/// graban ni se evalúan, ver RecommendedExerciseCatalogScreen — un
/// concepto distinto a la medición, aunque ambos son "ejercicios" en
/// lenguaje común) y "Mi progreso". Todo lo que no es específico de este
/// paciente (catálogo completo de mediciones, prueba rápida libre,
/// sesiones guardadas) queda detrás del logo/ícono de menú arriba a la
/// izquierda (el mismo logo de Fisiometric, sin un segundo logo grande
/// aparte), para que esta pantalla quede especializada solo en lo suyo.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.patientProfile});

  final PatientProfile patientProfile;

  @override
  Widget build(BuildContext context) {
    // Los movimientos sagitales del catálogo están codificados como
    // `derecha` por defecto — se ajustan al lado real que el paciente
    // indicó en PatientGateScreen. Los frontales muestran los dos lados en
    // el mismo cuadro, así que en su caso se restringe qué articulación se
    // mide (no la vista de cámara) — ver Exercise.forPatientSide.
    final todaysMeasurements = exerciseCatalog
        .where((e) => patientProfile.pathology.exerciseIds.contains(e.id))
        .map((e) => e.forPatientSide(patientProfile.affectedSide))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.tealPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Row(
                children: [
                  PopupMenuButton<_MoreMenuItem>(
                    icon: ClipOval(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        color: Colors.white,
                        child: Image.asset('assets/icon/icon.png', width: 26, height: 26),
                      ),
                    ),
                    onSelected: (item) {
                      switch (item) {
                        case _MoreMenuItem.quickTest:
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  QuickTestViewScreen(patientName: patientProfile.name),
                            ),
                          );
                        case _MoreMenuItem.fullCatalog:
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExerciseCatalogScreen(
                                patientName: patientProfile.name,
                                affectedSide: patientProfile.affectedSide,
                              ),
                            ),
                          );
                        case _MoreMenuItem.savedSessions:
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SessionsListScreen()),
                          );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _MoreMenuItem.quickTest,
                        child: ListTile(
                          leading: Icon(Icons.speed_outlined),
                          title: Text('Prueba rápida'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _MoreMenuItem.fullCatalog,
                        child: ListTile(
                          leading: Icon(Icons.fitness_center_outlined),
                          title: Text('Catálogo completo'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _MoreMenuItem.savedSessions,
                        child: ListTile(
                          leading: Icon(Icons.folder_open_outlined),
                          title: Text('Sesiones guardadas'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Hola, ${patientProfile.name}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${patientProfile.age} años · ${patientProfile.pathology.label}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Medición del día de hoy',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No son ejercicios para repetir — son los movimientos que '
                      'se registran hoy para seguir tu rango de movimiento.',
                      style: TextStyle(
                        color: AppColors.darkGrey.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final exercise in todaysMeasurements) ...[
                      _TodaysMeasurementCard(
                        exercise: exercise,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExerciseDemoScreen(
                              exercise: exercise,
                              videoAssetPath: exercise.videoAssetPathFor(
                                patientProfile.affectedSide,
                              ),
                              patientName: patientProfile.name,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    _HomeOptionCard(
                      icon: Icons.self_improvement_outlined,
                      accentColor: AppColors.orangeAccent,
                      title: 'Ejercicios recomendados',
                      subtitle:
                          'Ejercicios terapéuticos para tu patología — estos no se '
                          'graban ni se evalúan, son para repetir por tu cuenta.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              RecommendedExerciseCatalogScreen(pathology: patientProfile.pathology),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _HomeOptionCard(
                      icon: Icons.show_chart_outlined,
                      accentColor: AppColors.tealPrimary,
                      title: 'Mi progreso',
                      subtitle:
                          'Cómo ha ido cambiando tu rango de movimiento sesión '
                          'a sesión, y el detalle de cada medición realizada.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProgressScreen(patientProfile: patientProfile),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta grande y llamativa para cada movimiento de "Medición del día de
/// hoy" — mucho más prominente que el resto de las opciones del home, ya
/// que es la acción principal que se espera de esta pantalla.
class _TodaysMeasurementCard extends StatelessWidget {
  const _TodaysMeasurementCard({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tealPrimary,
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: AppColors.tealPrimary.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_outlined, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exercise.view.label,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Medir',
                  style: TextStyle(color: AppColors.tealPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeOptionCard extends StatelessWidget {
  const _HomeOptionCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: accentColor.withValues(alpha: 0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.darkGrey.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}
