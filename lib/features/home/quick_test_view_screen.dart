import 'package:flutter/material.dart';

import '../../core/pose/body_view.dart';
import '../../tema/app_colors.dart';
import '../medicion/joint_choice.dart';
import '../medicion/measurement_protocol_screen.dart';
import '../medicion/widgets/body_view_toggle.dart';

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
  JointChoice _joint = JointChoice.todas;

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
                  for (final choice in JointChoice.values)
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
