import 'package:flutter/material.dart';

import '../../../core/pose/angle_calculator.dart';
import '../../../core/pose/body_region.dart';
import '../../../core/pose/body_view.dart';
import '../../../models/joint_angles.dart';
import '../../../models/joint_angular_velocity.dart';
import '../../../theme/app_colors.dart';

/// Franja numérica con los ángulos articulares del lado activo según
/// [view] y su velocidad angular — se extiende a lo ancho, arriba de la
/// cámara, en vez de ser una columna angosta a un costado, para no tapar
/// el cuerpo de la persona en el encuadre. Siempre muestra las mismas
/// celdas para la vista activa — "—" cuando un valor no está disponible —
/// para que el layout nunca "salte" al perderse/recuperarse la detección
/// de una articulación.
class AngleHudPanel extends StatelessWidget {
  const AngleHudPanel({
    super.key,
    required this.angles,
    required this.velocity,
    required this.view,
    required this.region,
    this.trackedJoints,
  });

  final JointAngles angles;
  final JointAngularVelocity velocity;
  final BodyView view;

  /// Qué articulaciones mostrar — un ejercicio de tren superior no muestra
  /// la celda de rodilla, y viceversa (ver BodyRegion).
  final BodyRegion region;

  /// Restringe aún más allá de [region] — p.ej. abducción de hombro solo
  /// muestra hombro, no codo/muñeca, aunque las 3 sean "tren superior".
  /// `null` (sin ejercicio específico, como en "Prueba rápida") no
  /// restringe nada más que [region].
  final Set<JointKind>? trackedJoints;

  @override
  Widget build(BuildContext context) {
    final isFrontal = view == BodyView.frontal;

    bool isActive(JointKind kind) =>
        isJointActiveForRegion(kind, region) &&
        (trackedJoints == null || trackedJoints!.contains(kind));

    final cells = <JointKind>[
      for (final (izq, der) in jointPairs)
        if (isActive(izq) || isActive(der))
          if (isFrontal) ...[izq, der] else (view == BodyView.izquierda ? izq : der),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runSpacing: 6,
        children: [
          for (final kind in cells) _AngleCell(kind: kind, angles: angles, velocity: velocity),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
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
    );
  }
}
