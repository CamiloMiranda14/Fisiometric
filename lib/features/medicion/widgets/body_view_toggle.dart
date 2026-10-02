import 'package:flutter/material.dart';

import '../../../core/pose/body_view.dart';

/// Selector "Vista frontal" / "Vista izquierda" / "Vista derecha". Se
/// bloquea por completo mientras hay una grabación en curso, igual que
/// RecordingModeToggle — no tiene sentido cambiar de vista a mitad de una
/// toma.
class BodyViewToggle extends StatelessWidget {
  const BodyViewToggle({
    super.key,
    required this.view,
    required this.onChanged,
    required this.locked,
  });

  final BodyView view;
  final ValueChanged<BodyView> onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BodyView>(
      segments: [
        for (final v in BodyView.values)
          ButtonSegment(value: v, label: Text(v.label)),
      ],
      selected: {view},
      onSelectionChanged: locked
          ? null
          : (selection) => onChanged(selection.first),
    );
  }
}
