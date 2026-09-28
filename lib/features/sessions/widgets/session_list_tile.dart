import 'package:flutter/material.dart';

import '../../../core/utils/session_naming.dart';
import '../../../models/recording_mode.dart';
import '../../../models/session_metadata.dart';
import '../../../theme/app_colors.dart';

class SessionListTile extends StatelessWidget {
  const SessionListTile({super.key, required this.metadata, required this.onTap});

  final SessionMetadata metadata;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = formatDateWords(metadata.startedAt);
    final durationLabel = '${(metadata.durationMs / 1000).toStringAsFixed(0)} s';
    final modeLabel = metadata.mode == RecordingMode.clean
        ? 'Video limpio'
        : 'Overlay quemado';
    final modeIcon = metadata.mode == RecordingMode.clean
        ? Icons.videocam_outlined
        : Icons.layers_outlined;
    final viewLabel = metadata.view.label;

    final patientName = metadata.patientName;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.tealPrimary,
        child: Icon(modeIcon, color: Colors.white),
      ),
      title: Text(
        patientName == null || patientName.isEmpty
            ? dateLabel
            : '$patientName · $dateLabel',
      ),
      subtitle: Text(
        '$durationLabel · ${metadata.sampleCount} muestras · $modeLabel · $viewLabel'
        '${metadata.recordedByTherapist ? ' · Fisioterapeuta' : ''}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
