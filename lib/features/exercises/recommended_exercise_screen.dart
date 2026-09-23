import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/pose/angle_calculator.dart';
import '../../models/recommended_exercise.dart';
import '../../services/patient/patient_profile_service.dart';
import '../../services/storage/session_loader.dart';
import '../../services/storage/session_storage_service.dart';
import '../../theme/app_colors.dart';
import 'exercise_catalog.dart';

/// Muestra el video de un ejercicio terapéutico recomendado, grabado por un
/// profesional — a diferencia de ExerciseDemoScreen, acá no hay "Empezar
/// medición": este ejercicio no se graba ni se evalúa, el paciente solo lo
/// mira para repetirlo por su cuenta.
///
/// Si [exercise] tiene un requisito de rango de movimiento (ver
/// RecommendedExercise.requirementExerciseId), primero se revisan las
/// sesiones guardadas de [patientProfile] para saber si ya lo alcanzó —
/// mientras no lo alcance, se muestra el requisito en vez del video, para
/// que sepa qué le falta en vez de encontrarse la pantalla vacía o rota.
class RecommendedExerciseScreen extends StatefulWidget {
  const RecommendedExerciseScreen({
    super.key,
    required this.exercise,
    required this.patientProfile,
  });

  final RecommendedExercise exercise;
  final PatientProfile patientProfile;

  @override
  State<RecommendedExerciseScreen> createState() => _RecommendedExerciseScreenState();
}

class _RecommendedExerciseScreenState extends State<RecommendedExerciseScreen> {
  VideoPlayerController? _controller;
  late final Future<double?> _bestRomFuture;

  @override
  void initState() {
    super.initState();
    _bestRomFuture = _loadBestRom();
  }

  /// Mejor (mayor) rango logrado por el paciente en
  /// `exercise.requirementExerciseId`, entre todas sus sesiones guardadas —
  /// `null` si el ejercicio no tiene requisito, o si el paciente todavía no
  /// tiene ninguna sesión válida de ese ejercicio.
  Future<double?> _loadBestRom() async {
    final requirementId = widget.exercise.requirementExerciseId;
    if (requirementId == null) return null;

    final exercise = exerciseForId(requirementId);
    final joint = exercise?.trackedJointFor(widget.patientProfile.affectedSide);
    if (exercise == null || joint == null) return null;
    final def = jointDefinitions.firstWhere((d) => d.kind == joint);

    final all = await loadAllSessions(SessionStorageService());
    final values = all
        .where(
          (s) =>
              s.metadata.patientName == widget.patientProfile.name &&
              s.metadata.exerciseId == requirementId,
        )
        .map((s) => s.metadata.jointStats[def.csvColumn]?.max)
        .whereType<double>();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  void _initVideo() {
    if (_controller != null) return;
    final controller = VideoPlayerController.asset(widget.exercise.videoAssetPath);
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      controller
        ..setLooping(true)
        ..play();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: SafeArea(
        child: FutureBuilder<double?>(
          future: _bestRomFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final minRom = widget.exercise.requirementMinRom;
            final bestRom = snapshot.data;
            final locked = minRom != null && (bestRom == null || bestRom < minRom);
            if (locked) {
              return _LockedRequirement(exercise: widget.exercise, bestRom: bestRom);
            }
            _initVideo();
            return _VideoAndDescription(exercise: widget.exercise, controller: _controller);
          },
        ),
      ),
    );
  }
}

/// Video + descripción, una vez que el requisito (si lo hay) ya se cumplió.
class _VideoAndDescription extends StatelessWidget {
  const _VideoAndDescription({required this.exercise, required this.controller});

  final RecommendedExercise exercise;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ColoredBox(
            color: Colors.black,
            child: Builder(
              builder: (context) {
                final c = controller;
                if (c == null || !c.value.isInitialized) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.orangeAccent),
                  );
                }
                return AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tealPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Ejercicio recomendado — no se graba ni se evalúa',
                    style: TextStyle(color: AppColors.tealPrimary, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  exercise.description,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Se muestra en vez del video mientras el paciente no alcance
/// [RecommendedExercise.requirementMinRom] — explica el requisito y, si ya
/// tiene alguna medición, cuánto le falta, en vez de solo negarle el acceso.
class _LockedRequirement extends StatelessWidget {
  const _LockedRequirement({required this.exercise, required this.bestRom});

  final RecommendedExercise exercise;
  final double? bestRom;

  @override
  Widget build(BuildContext context) {
    final minRom = exercise.requirementMinRom!;
    final missing = bestRom == null ? null : (minRom - bestRom!).clamp(0, minRom);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.orangeAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: AppColors.orangeAccent, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Todavía no está disponible',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              'Este es un ejercicio de fase avanzada — se desbloquea cuando '
              'tu medición registre al menos ${minRom.round()}° de rango.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.darkGrey.withValues(alpha: 0.75), fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (bestRom != null)
              Text(
                'Tu mejor medición hasta ahora: ${bestRom!.round()}° · '
                'te faltan ${missing!.round()}°.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.tealPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            else
              Text(
                'Todavía no tienes ninguna medición registrada — hazla primero '
                'desde "Medición del día de hoy".',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.darkGrey.withValues(alpha: 0.75), fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }
}
