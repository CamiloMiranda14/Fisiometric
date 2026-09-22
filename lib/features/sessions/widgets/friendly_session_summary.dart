import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/pose/angle_calculator.dart';
import '../../../core/pose/body_region.dart';
import '../../../core/pose/body_view.dart';
import '../../../models/pathology.dart';
import '../../../models/session_metadata.dart';
import '../../../services/storage/session_loader.dart';
import '../../../services/storage/session_storage_service.dart';
import '../../../theme/app_colors.dart';
import '../../exercises/exercise_catalog.dart';

/// Resumen de la sesión pensado para que lo lea el propio paciente, no un
/// profesional: un número grande ("lograste X°"), una barra simple de
/// progreso hacia el objetivo clínico (en vez de un eje con números como
/// `MovementChart`), y una frase comparándolo con la sesión anterior. La
/// gráfica técnica sigue disponible aparte para quien la quiera ver.
class FriendlySessionSummary extends StatefulWidget {
  const FriendlySessionSummary({super.key, required this.dir, required this.metadata});

  final Directory dir;
  final SessionMetadata metadata;

  @override
  State<FriendlySessionSummary> createState() => _FriendlySessionSummaryState();
}

class _JointResult {
  const _JointResult({
    required this.def,
    required this.rawMax,
    required this.target,
    required this.previousMax,
  });

  final JointDefinition def;

  /// Ya en la convención "0° = extendido, sube con la flexión" en la que
  /// `JointAngles.fromPoseFrame` guarda todo ángulo — no hace falta
  /// convertir nada acá, a diferencia de antes.
  final double rawMax;
  final double? target;
  final double? previousMax;
}

class _FriendlySessionSummaryState extends State<FriendlySessionSummary> {
  late final Future<List<_JointResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_JointResult>> _load() async {
    final metadata = widget.metadata;
    final trackedJoints = trackedJointsForExerciseId(metadata.exerciseId);
    final activeDefs = jointDefinitions.where(
      (d) =>
          isJointActiveForView(d.kind, metadata.view) &&
          isJointActiveForRegion(d.kind, metadata.region) &&
          (trackedJoints == null || trackedJoints.contains(d.kind)),
    );

    final target = metadata.exerciseId == null
        ? null
        : pathologyForExercise(metadata.exerciseId!)?.targetRomFor(metadata.exerciseId!);

    List<SavedSession>? sameExerciseSessions;
    if (metadata.exerciseId != null) {
      final all = await loadAllSessions(SessionStorageService());
      sameExerciseSessions = all
          .where(
            (s) =>
                s.metadata.exerciseId == metadata.exerciseId &&
                s.metadata.patientName == metadata.patientName &&
                s.metadata.startedAt.isBefore(metadata.startedAt),
          )
          .toList()
        ..sort((a, b) => b.metadata.startedAt.compareTo(a.metadata.startedAt));
    }

    final results = <_JointResult>[];
    for (final def in activeDefs) {
      final stats = metadata.jointStats[def.csvColumn];
      if (stats == null) continue;

      final previous = sameExerciseSessions?.firstOrNull;
      final previousMax = previous?.metadata.jointStats[def.csvColumn]?.max;

      results.add(
        _JointResult(
          def: def,
          rawMax: stats.max,
          target: target,
          previousMax: previousMax,
        ),
      );
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_JointResult>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No hay suficientes datos para mostrar un resumen de esta sesión.',
              style: TextStyle(color: AppColors.lowConfidence),
            ),
          );
        }
        return Column(
          children: [
            for (final result in results) ...[
              _FriendlyJointCard(result: result),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _FriendlyJointCard extends StatelessWidget {
  const _FriendlyJointCard({required this.result});

  final _JointResult result;

  @override
  Widget build(BuildContext context) {
    final target = result.target;
    final fraction = target == null ? null : (result.rawMax / target).clamp(0.0, 1.0);
    final reachedTarget = target != null && result.rawMax >= target;

    String? comparisonText;
    IconData? comparisonIcon;
    Color? comparisonColor;
    final previous = result.previousMax;
    if (previous != null) {
      final delta = result.rawMax - previous;
      if (delta.abs() < 2) {
        comparisonText = 'Similar a tu sesión anterior';
        comparisonIcon = Icons.trending_flat;
        comparisonColor = AppColors.darkGrey;
      } else if (delta > 0) {
        comparisonText = '${delta.round()}° más que tu sesión anterior';
        comparisonIcon = Icons.trending_up;
        comparisonColor = AppColors.success;
      } else {
        comparisonText = '${delta.abs().round()}° menos que tu sesión anterior';
        comparisonIcon = Icons.trending_down;
        comparisonColor = AppColors.orangeAccent;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.tealPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tealPrimary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.def.label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${result.rawMax.round()}°',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tealPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'lograste hoy',
                  style: TextStyle(color: AppColors.darkGrey, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (fraction != null && target != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 16,
                backgroundColor: AppColors.lowConfidence.withValues(alpha: 0.18),
                color: reachedTarget ? AppColors.success : AppColors.tealPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reachedTarget
                  ? '¡Alcanzaste el objetivo de movimiento (${target.round()}°)!'
                  : 'Objetivo: ${target.round()}° · te faltan ${(target - result.rawMax).round()}°',
              style: TextStyle(
                fontSize: 12,
                color: reachedTarget ? AppColors.success : AppColors.darkGrey.withValues(alpha: 0.7),
                fontWeight: reachedTarget ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
          if (comparisonText != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(comparisonIcon, size: 16, color: comparisonColor),
                const SizedBox(width: 6),
                Text(comparisonText, style: TextStyle(fontSize: 12, color: comparisonColor)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
