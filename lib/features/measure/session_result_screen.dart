import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/pose/angle_calculator.dart';
import '../../core/pose/body_region.dart';
import '../../core/pose/body_view.dart';
import '../../models/session_metadata.dart';
import '../../services/patient/patient_profile_service.dart';
import '../../theme/app_colors.dart';
import '../exercises/exercise_catalog.dart';
import '../home/home_screen.dart';
import '../progress/progress_screen.dart';
import '../sessions/session_detail_screen.dart';
import 'measurement_protocol_screen.dart';

/// Se muestra justo al terminar de grabar un ejercicio (en vez de solo un
/// aviso momentáneo) — el rango máximo alcanzado por articulación, y desde
/// acá el paciente elige si repite la medición o pasa a ver los resultados
/// completos de la sesión (donde también puede eliminarla — ver
/// SessionDetailScreen).
class SessionResultScreen extends StatelessWidget {
  const SessionResultScreen({super.key, required this.dir, required this.metadata});

  final Directory dir;
  final SessionMetadata metadata;

  /// Recarga el perfil del paciente (guardado en PatientGateScreen) para
  /// poder reconstruir HomeScreen/ProgressScreen — SessionMetadata solo
  /// guarda el nombre, no la patología/edad/lado completos.
  Future<PatientProfile?> _loadProfile() => const PatientProfileService().loadLast();

  Future<void> _goHome(BuildContext context) async {
    final profile = await _loadProfile();
    if (profile == null || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(patientProfile: profile)),
      (route) => false,
    );
  }

  Future<void> _goProgress(BuildContext context) async {
    final profile = await _loadProfile();
    if (profile == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProgressScreen(patientProfile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackedJoints = trackedJointsForExerciseId(metadata.exerciseId);
    final activeDefs = jointDefinitions
        .where(
          (d) =>
              isJointActiveForView(d.kind, metadata.view) &&
              isJointActiveForRegion(d.kind, metadata.region) &&
              (trackedJoints == null || trackedJoints.contains(d.kind)),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado del ejercicio')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 64,
              ),
              const SizedBox(height: 12),
              const Text(
                '¡Medición guardada!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (metadata.patientName != null && metadata.patientName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  metadata.patientName!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.darkGrey.withValues(alpha: 0.7)),
                ),
              ],
              const SizedBox(height: 28),
              const Text(
                'Rango máximo alcanzado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    for (final def in activeDefs)
                      _MaxRangeRow(label: def.label, stats: metadata.jointStats[def.csvColumn]),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.replay),
                label: const Text('Repetir medición'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MeasurementProtocolScreen(
                      initialView: metadata.view,
                      region: metadata.region,
                      patientName: metadata.patientName ?? '',
                      exerciseId: metadata.exerciseId,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.bar_chart_outlined),
                label: const Text('Ver resultados completos'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(dir: dir, metadata: metadata),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.show_chart_outlined),
                label: const Text('Ver mi progreso'),
                onPressed: () => _goProgress(context),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.home_outlined),
                label: const Text('Volver al inicio'),
                onPressed: () => _goHome(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaxRangeRow extends StatelessWidget {
  const _MaxRangeRow({required this.label, required this.stats});

  final String label;
  final JointStats? stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            stats == null ? 'Sin datos suficientes' : '${stats!.max.round()}°',
            style: TextStyle(
              fontSize: stats == null ? 14 : 22,
              fontWeight: FontWeight.bold,
              color: stats == null ? AppColors.lowConfidence : AppColors.tealPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
