import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/pose/angle_calculator.dart';
import '../../core/pose/body_view.dart';
import '../../models/recording_mode.dart';
import '../../models/session_metadata.dart';
import '../../services/storage/session_storage_service.dart';
import '../../theme/app_colors.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.dir, required this.metadata});

  final Directory dir;
  final SessionMetadata metadata;

  Future<void> _share() async {
    final candidates = [
      File('${dir.path}/${metadata.videoFileName}'),
      File('${dir.path}/datos.csv'),
      File('${dir.path}/datos.xlsx'),
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
          _InfoRow(
            label: 'Duración',
            value: '${(metadata.durationMs / 1000).toStringAsFixed(1)} s',
          ),
          _InfoRow(label: 'Muestras', value: '${metadata.sampleCount}'),
          _InfoRow(label: 'Modo', value: modeLabel),
          _InfoRow(label: 'Vista', value: metadata.view.label),
          const SizedBox(height: 24),
          Text(
            'Ángulos (mín / prom / máx)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          for (final def in jointDefinitions)
            if (isJointActiveForView(def.kind, metadata.view))
              _JointStatsRow(def: def, stats: metadata.jointStats[def.csvColumn]),
        ],
      ),
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
