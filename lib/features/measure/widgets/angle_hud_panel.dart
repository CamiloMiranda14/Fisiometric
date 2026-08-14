import 'package:flutter/material.dart';

import '../../../core/pose/angle_calculator.dart';
import '../../../models/joint_angles.dart';
import '../../../theme/app_colors.dart';

/// Panel numérico con los 8 ángulos articulares. Siempre muestra las mismas
/// 8 filas — "—" cuando el valor no está disponible — para que el layout
/// nunca "salte" al perderse/recuperarse la detección de una articulación.
class AngleHudPanel extends StatelessWidget {
  const AngleHudPanel({super.key, required this.angles});

  final JointAngles angles;

  static const List<(JointKind, JointKind)> _pairedRows = [
    (JointKind.hombroIzq, JointKind.hombroDer),
    (JointKind.codoIzq, JointKind.codoDer),
    (JointKind.munecaIzq, JointKind.munecaDer),
    (JointKind.rodillaIzq, JointKind.rodillaDer),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final pair in _pairedRows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AngleCell(kind: pair.$1, value: angles.forJoint(pair.$1)),
                  const SizedBox(width: 14),
                  _AngleCell(kind: pair.$2, value: angles.forJoint(pair.$2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AngleCell extends StatelessWidget {
  const _AngleCell({required this.kind, required this.value});

  final JointKind kind;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final label = jointDefinitions.firstWhere((d) => d.kind == kind).label;
    final text = value == null ? '—' : '${value!.round()}°';
    return SizedBox(
      width: 112,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Text(
            text,
            style: TextStyle(
              color: value == null ? AppColors.lowConfidence : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
