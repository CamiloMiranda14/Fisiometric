import 'package:flutter/material.dart';

import '../../core/pose/angle_calculator.dart';
import '../../core/pose/body_region.dart';
import '../../core/pose/body_view.dart';
import '../../theme/app_colors.dart';
import '../measure/measurement_protocol_screen.dart';
import '../measure/widgets/body_view_toggle.dart';

/// Qué articulación medir en la "prueba rápida" — a diferencia del flujo de
/// ejercicios (donde `Exercise.trackedJoints` ya viene fijo), acá el
/// paciente la elige él mismo, o "Todas" para no restringir nada (mide y
/// muestra cualquier articulación que la vista deje ver).
enum _JointChoice { hombro, codo, muneca, cadera, rodilla, todas }

extension on _JointChoice {
  String get label => switch (this) {
    _JointChoice.hombro => 'Hombro',
    _JointChoice.codo => 'Codo',
    _JointChoice.muneca => 'Muñeca',
    _JointChoice.cadera => 'Cadera',
    _JointChoice.rodilla => 'Rodilla',
    _JointChoice.todas => 'Todas (cuerpo completo)',
  };

  /// `null` = no restringe articulaciones (caso "todas").
  Set<JointKind>? get trackedJoints => switch (this) {
    _JointChoice.hombro => const {JointKind.hombroIzq, JointKind.hombroDer},
    _JointChoice.codo => const {JointKind.codoIzq, JointKind.codoDer},
    _JointChoice.muneca => const {JointKind.munecaIzq, JointKind.munecaDer},
    _JointChoice.cadera => const {JointKind.caderaIzq, JointKind.caderaDer},
    _JointChoice.rodilla => const {JointKind.rodillaIzq, JointKind.rodillaDer},
    _JointChoice.todas => null,
  };

  BodyRegion get region => switch (this) {
    _JointChoice.hombro || _JointChoice.codo || _JointChoice.muneca => BodyRegion.upperBody,
    _JointChoice.cadera || _JointChoice.rodilla => BodyRegion.lowerBody,
    _JointChoice.todas => BodyRegion.fullBody,
  };
}

/// Selección manual de vista y articulación para la "prueba rápida" — a
/// diferencia del flujo de ejercicios (donde ambas vienen preconfiguradas
/// según el ejercicio elegido), aquí el usuario las elige él mismo antes de
/// entrar a medir en vivo.
class QuickTestViewScreen extends StatefulWidget {
  const QuickTestViewScreen({super.key, required this.patientName});

  /// Ingresado en PatientGateScreen al abrir la app.
  final String patientName;

  @override
  State<QuickTestViewScreen> createState() => _QuickTestViewScreenState();
}

class _QuickTestViewScreenState extends State<QuickTestViewScreen> {
  BodyView _view = BodyView.frontal;
  _JointChoice _joint = _JointChoice.todas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba rápida')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.speed_outlined,
                size: 56,
                color: AppColors.tealPrimary,
              ),
              const SizedBox(height: 24),
              const Text(
                '¿Desde qué vista vas a medir?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              BodyViewToggle(
                view: _view,
                locked: false,
                onChanged: (v) => setState(() => _view = v),
              ),
              const SizedBox(height: 28),
              const Text(
                '¿Qué articulación querés medir?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final choice in _JointChoice.values)
                    ChoiceChip(
                      label: Text(choice.label),
                      selected: _joint == choice,
                      onSelected: (_) => setState(() => _joint = choice),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MeasurementProtocolScreen(
                      initialView: _view,
                      patientName: widget.patientName,
                      region: _joint.region,
                      trackedJoints: _joint.trackedJoints,
                    ),
                  ),
                ),
                child: const Text('Empezar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
