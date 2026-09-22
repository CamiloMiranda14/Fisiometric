import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/pose/angle_calculator.dart';
import '../../core/pose/body_region.dart';
import '../../core/pose/body_view.dart';
import '../../models/recording_mode.dart';
import '../../models/session_metadata.dart';
import '../../services/storage/session_storage_service.dart';
import '../../theme/app_colors.dart';
import '../exercises/exercise_catalog.dart';
import 'widgets/friendly_session_summary.dart';
import 'widgets/movement_chart.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.dir, required this.metadata});

  final Directory dir;
  final SessionMetadata metadata;

  Future<void> _share() async {
    final candidates = [
      File('${dir.path}/${metadata.videoFileName}'),
      File('${dir.path}/datos.csv'),
    ];
    final files = <XFile>[
      for (final f in candidates)
        if (await f.exists()) XFile(f.path),
    ];
    if (files.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(files: files, subject: 'Sesión Fisiometric ${metadata.id}'),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar esta sesión?'),
        content: const Text(
          'Se borrará el video y los datos. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await SessionStorageService().deleteSession(dir);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final modeLabel = metadata.mode == RecordingMode.clean
        ? 'Video limpio'
        : 'Overlay quemado';
    final trackedJoints = trackedJointsForExerciseId(metadata.exerciseId);
    bool isActive(JointKind kind) =>
        isJointActiveForView(kind, metadata.view) &&
        isJointActiveForRegion(kind, metadata.region) &&
        (trackedJoints == null || trackedJoints.contains(kind));

    return Scaffold(
      appBar: AppBar(
        title: Text(metadata.id),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: _share),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SessionVideoPlayer(videoFile: File('${dir.path}/${metadata.videoFileName}')),
          const SizedBox(height: 20),
          if (metadata.patientName != null && metadata.patientName!.isNotEmpty)
            _InfoRow(label: 'Paciente', value: metadata.patientName!),
          _InfoRow(
            label: 'Duración',
            value: '${(metadata.durationMs / 1000).toStringAsFixed(1)} s',
          ),
          _InfoRow(label: 'Muestras', value: '${metadata.sampleCount}'),
          _InfoRow(label: 'Modo', value: modeLabel),
          _InfoRow(label: 'Vista', value: metadata.view.label),
          const SizedBox(height: 24),
          Text(
            'Resumen de tu medición',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          FriendlySessionSummary(dir: dir, metadata: metadata),
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Ver gráfica técnica detallada',
                style: TextStyle(fontSize: 13, color: AppColors.darkGrey),
              ),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              children: [MovementChart(dir: dir, metadata: metadata)],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ángulos (mín / prom / máx)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          for (final def in jointDefinitions)
            if (isActive(def.kind))
              _JointStatsRow(def: def, stats: metadata.jointStats[def.csvColumn]),
          const SizedBox(height: 24),
          Text(
            'Velocidad angular (promedio)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          for (final def in jointDefinitions)
            if (isActive(def.kind))
              _AverageRow(
                label: def.label,
                value: metadata.velocityStats[def.csvColumn],
                unit: '°/s',
              ),
        ],
      ),
    );
  }
}

/// Reproductor del video grabado en esta sesión — antes solo se podía ver
/// compartiéndolo afuera de la app; ahora se ve inline, igual que el video
/// de demostración en ExerciseDemoScreen.
class _SessionVideoPlayer extends StatefulWidget {
  const _SessionVideoPlayer({required this.videoFile});

  final File videoFile;

  @override
  State<_SessionVideoPlayer> createState() => _SessionVideoPlayerState();
}

class _SessionVideoPlayerState extends State<_SessionVideoPlayer> {
  VideoPlayerController? _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
  }

  Future<void> _init() async {
    if (!await widget.videoFile.exists()) return;
    final controller = VideoPlayerController.file(widget.videoFile);
    _controller = controller;
    await controller.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        final controller = _controller;
        if (snapshot.connectionState != ConnectionState.done || controller == null) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No se encontró el video de esta sesión.',
                style: TextStyle(color: AppColors.lowConfidence),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                VideoProgressIndicator(controller, allowScrubbing: true),
                IconButton(
                  iconSize: 48,
                  color: Colors.white,
                  icon: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => Icon(
                      controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                    ),
                  ),
                  onPressed: () => setState(() {
                    controller.value.isPlaying ? controller.pause() : controller.play();
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _AverageRow extends StatelessWidget {
  const _AverageRow({required this.label, required this.value, required this.unit});

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Sin datos suficientes'
        : '${value!.toStringAsFixed(1)}$unit';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            text,
            style: TextStyle(
              color: value == null ? AppColors.lowConfidence : AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _JointStatsRow extends StatelessWidget {
  const _JointStatsRow({required this.def, required this.stats});

  final JointDefinition def;
  final JointStats? stats;

  @override
  Widget build(BuildContext context) {
    final text = stats == null
        ? 'Sin datos suficientes'
        : '${stats!.min.round()}° / ${stats!.avg.round()}° / ${stats!.max.round()}°';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(def.label),
          Text(
            text,
            style: TextStyle(
              color: stats == null ? AppColors.lowConfidence : AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }
}
