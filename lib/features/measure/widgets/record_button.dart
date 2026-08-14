import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

enum RecordButtonState { idle, recording, saving }

class RecordButton extends StatelessWidget {
  const RecordButton({super.key, required this.state, required this.onPressed});

  final RecordButtonState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isSaving = state == RecordButtonState.saving;
    final isRecording = state == RecordButtonState.recording;

    return FloatingActionButton.large(
      onPressed: isSaving ? null : onPressed,
      backgroundColor: isRecording ? AppColors.danger : AppColors.orangeAccent,
      child: isSaving
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            )
          : Icon(
              isRecording ? Icons.stop_rounded : Icons.fiber_manual_record,
              color: Colors.white,
              size: 32,
            ),
    );
  }
}
