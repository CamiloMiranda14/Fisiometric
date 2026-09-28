import 'package:flutter/material.dart';

import '../../core/pose/body_view.dart';
import '../../theme/app_colors.dart';
import '../measure/joint_choice.dart';
import '../measure/measure_screen.dart';
import '../measure/widgets/body_view_toggle.dart';

/// Punto de entrada para que un fisioterapeuta grabe con la cámara trasera
/// el rango articular real de un paciente — a diferencia del resto de la
/// app (pensada para que el propio paciente se mida con la frontal, sin
/// ayuda). Accesible directo desde PatientGateScreen, sin pasar por el
/// registro de paciente/patología: es una medición clínica puntual, no el
/// seguimiento diario en casa (ver MeasureScreen.therapistMode).
class TherapistModeScreen extends StatefulWidget {
  const TherapistModeScreen({super.key});

  @override
  State<TherapistModeScreen> createState() => _TherapistModeScreenState();
}

class _TherapistModeScreenState extends State<TherapistModeScreen> {
  final _nameController = TextEditingController();
  BodyView _view = BodyView.frontal;
  JointChoice _joint = JointChoice.todas;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modo fisioterapeuta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.medical_services_outlined,
                size: 56,
                color: AppColors.tealPrimary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Vas a grabar con la cámara trasera, apuntando al paciente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'No hay espera de alineación, graba cuando el paciente esté listo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.darkGrey.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del paciente (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                '¿Desde qué vista vas a grabar?',
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
                '¿Qué articulación vas a medir?',
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
                    builder: (_) => MeasureScreen(
                      initialView: _view,
                      region: _joint.region,
                      trackedJoints: _joint.trackedJoints,
                      patientName: _nameController.text.trim().isEmpty
                          ? null
                          : _nameController.text.trim(),
                      therapistMode: true,
                    ),
                  ),
                ),
                child: const Text('Empezar a grabar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
