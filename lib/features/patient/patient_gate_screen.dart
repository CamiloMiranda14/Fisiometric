import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/pose/body_view.dart';
import '../../models/pathology.dart';
import '../../services/notifications/daily_reminder_service.dart';
import '../../services/patient/patient_profile_service.dart';
import '../../theme/app_colors.dart';
import '../home/home_screen.dart';

/// Primera pantalla al abrir la app — pide nombre, edad y qué patología
/// presenta el paciente antes de dejar hacer cualquier otra cosa (no se
/// puede saltar). El mismo teléfono puede pasar de paciente en paciente
/// durante una jornada, así que se pregunta en cada apertura de la app, no
/// solo la primera vez — el último perfil ingresado se prellena como
/// comodidad, pero hay que confirmarlo o cambiarlo.
///
/// Con la patología elegida, HomeScreen puede guiar directo al paciente
/// hacia el/los ejercicio(s) que le corresponden (ver Pathology.exerciseIds)
/// en vez de que tenga que buscarlo en el catálogo completo.
class PatientGateScreen extends StatefulWidget {
  const PatientGateScreen({super.key});

  @override
  State<PatientGateScreen> createState() => _PatientGateScreenState();
}

class _PatientGateScreenState extends State<PatientGateScreen> {
  final _service = const PatientProfileService();
  final _cedulaController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Pathology? _pathology;
  BodyView? _affectedSide;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service.loadLast().then((profile) {
      if (!mounted) return;
      setState(() {
        if (profile != null) {
          _cedulaController.text = profile.cedula;
          _nameController.text = profile.name;
          _ageController.text = '${profile.age}';
          _pathology = profile.pathology;
          _affectedSide = profile.affectedSide;
        }
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || _pathology == null || _affectedSide == null) {
      // Fuerza a mostrar el error de los selectores (patología/lado), que
      // no son TextFormField y por eso no los revisa `validate()`.
      setState(() {});
      return;
    }
    final profile = PatientProfile(
      cedula: _cedulaController.text.trim(),
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      pathology: _pathology!,
      affectedSide: _affectedSide!,
    );
    await _service.save(profile);
    // No se espera — puede pedir permiso de notificaciones (diálogo del
    // sistema) y no debería demorar la navegación a Home.
    unawaited(DailyReminderService().refresh(profile));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(patientProfile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _loading ? Colors.white : AppColors.tealPrimary,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: Image(
                  image: AssetImage('assets/icon/icon.png'),
                  width: 160,
                  height: 160,
                ),
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            'assets/icon/icon.png',
                            width: 56,
                            height: 56,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '¿Quién va a medirse hoy?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Estos datos quedan guardados junto a cada sesión que grabes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _cedulaController,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: _fieldDecoration('Cédula'),
                          validator: (value) => (value == null || value.trim().isEmpty)
                              ? 'Ingresa la cédula para continuar'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: _fieldDecoration('Nombre del paciente'),
                          validator: (value) => (value == null || value.trim().isEmpty)
                              ? 'Ingresa un nombre para continuar'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: _fieldDecoration('Edad'),
                          validator: (value) {
                            final age = int.tryParse(value?.trim() ?? '');
                            if (age == null || age <= 0 || age > 130) {
                              return 'Ingresa una edad válida';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Pathology>(
                          initialValue: _pathology,
                          isExpanded: true,
                          dropdownColor: AppColors.tealPrimary,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _fieldDecoration('Patología').copyWith(
                            errorText: _pathology == null ? 'Elige una patología' : null,
                          ),
                          items: [
                            for (final p in Pathology.values)
                              DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p.label,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                          ],
                          onChanged: (value) => setState(() => _pathology = value),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '¿De qué lado presentas la patología?',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<BodyView>(
                            style: SegmentedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              foregroundColor: Colors.white,
                              selectedBackgroundColor: Colors.white,
                              selectedForegroundColor: AppColors.tealPrimary,
                            ),
                            segments: const [
                              ButtonSegment(value: BodyView.izquierda, label: Text('Izquierdo')),
                              ButtonSegment(value: BodyView.derecha, label: Text('Derecho')),
                            ],
                            selected: {?_affectedSide},
                            emptySelectionAllowed: true,
                            onSelectionChanged: (selection) =>
                                setState(() => _affectedSide = selection.firstOrNull),
                          ),
                        ),
                        if (_affectedSide == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Elige un lado',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.tealPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _continue,
                            child: const Text('Continuar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}
