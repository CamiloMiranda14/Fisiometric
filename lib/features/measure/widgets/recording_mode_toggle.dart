import 'package:flutter/material.dart';

import '../../../models/recording_mode.dart';

/// Selector "Video limpio" / "Overlay quemado". Se bloquea por completo
/// mientras hay una grabación en curso (no tiene sentido cambiar de modo a
/// mitad de una toma). El segmento "Overlay quemado" además puede llegar
/// deshabilitado por separado vía [overlayModeAvailable] mientras esa
/// funcionalidad no esté lista (ver OverlayVideoRecorder).
class RecordingModeToggle extends StatelessWidget {
  const RecordingModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.locked,
    this.overlayModeAvailable = true,
  });

  final RecordingMode mode;
  final ValueChanged<RecordingMode> onChanged;
  final bool locked;
  final bool overlayModeAvailable;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<RecordingMode>(
      segments: [
        const ButtonSegment(
          value: RecordingMode.clean,
          label: Text('Video limpio'),
          icon: Icon(Icons.videocam_outlined),
        ),
        ButtonSegment(
          value: RecordingMode.overlayBurned,
          label: const Text('Overlay quemado'),
          icon: const Icon(Icons.layers_outlined),
          enabled: overlayModeAvailable,
        ),
      ],
      selected: {mode},
      onSelectionChanged: locked
          ? null
          : (selection) => onChanged(selection.first),
    );
  }
}
