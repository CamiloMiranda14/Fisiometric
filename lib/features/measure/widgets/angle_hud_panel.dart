import 'package:flutter/material.dart';

import '../../../core/pose/angle_calculator.dart';
import '../../../core/pose/body_view.dart';
import '../../../models/bilateral_symmetry.dart';
import '../../../models/joint_angles.dart';
import '../../../models/joint_angular_velocity.dart';
import '../../../theme/app_colors.dart';

/// Panel numérico con los ángulos articulares del lado activo según [view],
/// su velocidad angular, y — solo en `BodyView.frontal` — la simetría
/// bilateral entre lados. Siempre muestra las mismas filas para la vista
/// activa — "—" cuando un valor no está disponible — para que el layout
/// nunca "salte" al perderse/recuperarse la detección de una articulación.
class AngleHudPanel extends StatelessWidget {
  const AngleHudPanel({
    super.key,
    required this.angles,
    required this.velocity,
    required this.symmetry,
    required this.view,
  });

  final JointAngles angles;
  final JointAngularVelocity velocity;
  final BilateralSymmetry symmetry;
  final BodyView view;

  @override
  Widget build(BuildContext context) {
    final isFrontal = view == BodyView.frontal;

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
          for (final def in symmetricJointPairs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: isFrontal
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AngleCell(kind: def.izq, angles: angles, velocity: velocity),
                        const SizedBox(width: 14),
                        _AngleCell(kind: def.der, angles: angles, velocity: velocity),
                      ],
                    )
                  : _AngleCell(
                      kind: view == BodyView.izquierda ? def.izq : def.der,
                      angles: angles,
                      velocity: velocity,
                    ),
            ),
          if (isFrontal) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(color: Colors.white24, height: 1),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'Simetría (SI %)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            for (final def in symmetricJointPairs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _SymmetryRow(
                  label: def.label,
                  value: symmetry.forPair(def.pair),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AngleCell extends StatelessWidget {
  const _AngleCell({
    required this.kind,
    required this.angles,
    required this.velocity,
  });

  final JointKind kind;
  final JointAngles angles;
  final JointAngularVelocity velocity;

  @override
  Widget build(BuildContext context) {
    final label = jointDefinitions.firstWhere((d) => d.kind == kind).label;
    final angleValue = angles.forJoint(kind);
    final velocityValue = velocity.forJoint(kind);
    final angleText = angleValue == null ? '—' : '${angleValue.round()}°';

    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Row(
            children: [
              Text(
                angleText,
                style: TextStyle(
                  color: angleValue == null ? AppColors.lowConfidence : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (velocityValue != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '${velocityValue.round()}°/s',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SymmetryRow extends StatelessWidget {
  const _SymmetryRow({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '—' : '${value!.toStringAsFixed(1)}%';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Text(
          text,
          style: TextStyle(
            color: value == null ? AppColors.lowConfidence : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
