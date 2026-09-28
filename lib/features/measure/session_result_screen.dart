import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/pose/angle_calculator.dart';
import '../../core/pose/body_region.dart';
import '../../core/pose/body_view.dart';
import '../../models/exercise.dart';
import '../../models/session_metadata.dart';
import '../../services/patient/patient_profile_service.dart';
import '../../services/storage/session_loader.dart';
import '../../services/storage/session_storage_service.dart';
import '../../theme/app_colors.dart';
import '../exercises/exercise_catalog.dart';
import '../exercises/exercise_demo_screen.dart';
import '../home/home_screen.dart';
import '../patient/patient_gate_screen.dart';
import '../progress/progress_screen.dart';
import '../sessions/session_detail_screen.dart';
import 'measure_screen.dart';
import 'measurement_protocol_screen.dart';

/// Se muestra justo al terminar de grabar un ejercicio (en vez de solo un
/// aviso momentáneo) — el rango máximo alcanzado por articulación, y desde
/// acá el paciente elige si repite la medición, pasa a la SIGUIENTE
/// medición del día (si su patología pide más de una y todavía le falta
/// alguna, ver [_computeNextExercise]), o ve los resultados completos de
/// la sesión (donde también puede eliminarla — ver SessionDetailScreen).
class SessionResultScreen extends StatefulWidget {
  const SessionResultScreen({super.key, required this.dir, required this.metadata});

  final Directory dir;
  final SessionMetadata metadata;

  @override
  State<SessionResultScreen> createState() => _SessionResultScreenState();
}

class _SessionResultScreenState extends State<SessionResultScreen> {
  final _storageService = SessionStorageService();
  late final Future<(PatientProfile?, Exercise?)> _nextFuture;

  @override
  void initState() {
    super.initState();
    _nextFuture = _computeNextExercise();
  }

  /// Recarga el perfil del paciente (guardado en PatientGateScreen) para
  /// poder reconstruir HomeScreen/ProgressScreen — SessionMetadata solo
  /// guarda el nombre, no la patología/edad/lado completos. Ya aprovechado
  /// para resolver, de paso, si le falta alguna otra medición del día.
  Future<(PatientProfile?, Exercise?)> _computeNextExercise() async {
    if (widget.metadata.recordedByTherapist) return (null, null);
    final profile = await const PatientProfileService().loadLast();
    final exerciseId = widget.metadata.exerciseId;
    if (profile == null || exerciseId == null) return (profile, null);

    // Solo aplica a patologías que piden más de una medición (p.ej. hombro:
    // flexión Y abducción) — el resto no tiene "siguiente" que ofrecer.
    final otherIds = profile.pathology.exerciseIds.where((id) => id != exerciseId).toList();
    if (otherIds.isEmpty) return (profile, null);

    final all = await loadAllSessions(SessionStorageService());
    final today = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;
    final doneTodayIds = all
        .where((s) => s.metadata.patientName == profile.name && isToday(s.metadata.startedAt))
        .map((s) => s.metadata.exerciseId)
        .whereType<String>()
        .toSet();

    for (final id in otherIds) {
      // Ya la hizo hoy — no se le vuelve a ofrecer, solo se muestra si de
      // verdad le falta alguna.
      if (doneTodayIds.contains(id)) continue;
      final exercise = exerciseForId(id);
      if (exercise != null) return (profile, exercise.forPatientSide(profile.affectedSide));
    }
    return (profile, null);
  }

  /// "Repetir" borra de una vez la medición recién grabada (ver
  /// [SessionStorageService.deleteSession]) — sin esto quedaba guardada en
  /// disco igual, y "repetir" solo agregaba una segunda toma al lado,
  /// nunca reemplazaba la primera. Pide confirmación aparte porque es
  /// irreversible: una vez borrada, esa toma no se puede recuperar.
  Future<void> _confirmAndRepeat(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Repetir el ejercicio?'),
        content: const Text(
          'Esta medición NO se va a guardar, se borra y vuelves a grabar '
          'desde cero. ¿Seguro que quieres repetirla?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, repetir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await _storageService.deleteSession(widget.dir);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        // Modo fisioterapeuta: va directo a grabar de nuevo (cámara trasera,
        // sin gate de alineación) — se salta MeasurementProtocolScreen
        // porque su texto está dirigido al paciente ("revisa esto antes de
        // empezar TÚ"), no a quien lo está grabando.
        builder: (_) => widget.metadata.recordedByTherapist
            ? MeasureScreen(
                initialView: widget.metadata.view,
                region: widget.metadata.region,
                patientName: widget.metadata.patientName,
                exerciseId: widget.metadata.exerciseId,
                trackedJoints: widget.metadata.trackedJoints,
                therapistMode: true,
              )
            : MeasurementProtocolScreen(
                initialView: widget.metadata.view,
                region: widget.metadata.region,
                patientName: widget.metadata.patientName ?? '',
                exerciseId: widget.metadata.exerciseId,
                trackedJoints: widget.metadata.trackedJoints,
              ),
      ),
    );
  }

  Future<void> _goHome(BuildContext context) async {
    if (widget.metadata.recordedByTherapist) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PatientGateScreen()),
        (route) => false,
      );
      return;
    }
    final profile = await const PatientProfileService().loadLast();
    if (profile == null || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(patientProfile: profile)),
      (route) => false,
    );
  }

  Future<void> _goProgress(BuildContext context) async {
    final profile = await const PatientProfileService().loadLast();
    if (profile == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProgressScreen(patientProfile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.metadata;
    final trackedJoints = metadata.trackedJoints;
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
              FutureBuilder<(PatientProfile?, Exercise?)>(
                future: _nextFuture,
                builder: (context, snapshot) {
                  final profile = snapshot.data?.$1;
                  final nextExercise = snapshot.data?.$2;
                  if (profile == null || nextExercise == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orangeAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text('Siguiente: ${nextExercise.name}'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExerciseDemoScreen(
                            exercise: nextExercise,
                            videoAssetPath: nextExercise.videoAssetPathFor(profile.affectedSide),
                            patientName: metadata.patientName ?? '',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Text(
                '¿No te convenció el resultado? Puedes repetir el ejercicio, '
                'esta toma no se guardará.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.darkGrey.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                icon: const Icon(Icons.replay),
                label: const Text('Repetir medición'),
                onPressed: () => _confirmAndRepeat(context),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.bar_chart_outlined),
                label: const Text('Ver resultados completos'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(dir: widget.dir, metadata: metadata),
                  ),
                ),
              ),
              // "Mi progreso" es el seguimiento en casa del propio paciente
              // — no aplica a una toma clínica del fisioterapeuta.
              if (!widget.metadata.recordedByTherapist) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.show_chart_outlined),
                  label: const Text('Ver mi progreso'),
                  onPressed: () => _goProgress(context),
                ),
              ],
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
