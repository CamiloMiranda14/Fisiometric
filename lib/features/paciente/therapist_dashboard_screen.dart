import 'package:flutter/material.dart';

import '../../core/pose/body_view.dart';
import '../../modelos/pathology.dart';
import '../../services/paciente/patient_profile_service.dart';
import '../../services/paciente/patient_roster_service.dart';
import '../../tema/app_colors.dart';
import '../progreso/progress_screen.dart';
import 'assign_recommended_exercises_screen.dart';
import 'therapist_mode_screen.dart';

/// Panel del fisioterapeuta — su lista de pacientes (ver
/// PatientRosterService, que se llena sola con quien pase por
/// PatientGateScreen, más los que el fisio agregue acá a mano), y desde
/// cada uno: asignar ejercicios recomendados, ver su progreso, o grabarle
/// una medición en vivo con la cámara trasera (ver TherapistModeScreen).
class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({super.key});

  @override
  State<TherapistDashboardScreen> createState() =>
      _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> {
  late Future<List<PatientProfile>> _future;

  @override
  void initState() {
    super.initState();
    _future = const PatientRosterService().loadAll();
  }

  void _refresh() {
    setState(() => _future = const PatientRosterService().loadAll());
  }

  Future<void> _addPatient() async {
    final added = await Navigator.of(context).push<PatientProfile>(
      MaterialPageRoute(builder: (_) => const _AddPatientScreen()),
    );
    if (added != null) _refresh();
  }

  void _openPatient(PatientProfile profile) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => _PatientActionsScreen(profile: profile),
          ),
        )
        .then((_) {
          // Por si se reasignaron ejercicios recomendados — refresca el nombre/
          // patología mostrados en la lista, aunque rara vez cambien acá.
          _refresh();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo fisioterapeuta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Medición libre (sin elegir paciente)',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TherapistModeScreen()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<PatientProfile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final patients = snapshot.data ?? const [];
          if (patients.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 56,
                      color: AppColors.lowConfidence,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Todavía no hay pacientes registrados en este teléfono.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _addPatient,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Agregar paciente'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: patients.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final patient = patients[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.tealPrimary,
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                title: Text(patient.name),
                subtitle: Text(
                  'CC ${patient.cedula} · ${patient.pathology.label}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openPatient(patient),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPatient,
        child: const Icon(Icons.person_add_alt_1_outlined),
      ),
    );
  }
}

/// Las 3 acciones del fisio sobre un paciente ya elegido.
class _PatientActionsScreen extends StatelessWidget {
  const _PatientActionsScreen({required this.profile});

  final PatientProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'CC ${profile.cedula} · ${profile.age} años · ${profile.pathology.label}',
            style: TextStyle(color: AppColors.darkGrey.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 20),
          _ActionCard(
            icon: Icons.self_improvement_outlined,
            accentColor: AppColors.orangeAccent,
            title: 'Asignar ejercicios recomendados',
            subtitle:
                'Elige a mano cuáles le aparecen, en vez de los de su patología.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AssignRecommendedExercisesScreen(profile: profile),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ActionCard(
            icon: Icons.show_chart_outlined,
            accentColor: AppColors.tealPrimary,
            title: 'Ver progreso',
            subtitle: 'Su calendario de mediciones y el avance por ejercicio.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProgressScreen(patientProfile: profile),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ActionCard(
            icon: Icons.videocam_outlined,
            accentColor: AppColors.danger,
            title: 'Grabar medición',
            subtitle: 'Cámara trasera, en vivo, del ángulo que elijas.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TherapistModeScreen(initialPatientName: profile.name),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: accentColor.withValues(alpha: 0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.darkGrey.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formulario simple para que el fisio agregue un paciente que todavía no
/// ha usado el teléfono por su cuenta — mismos campos que PatientGateScreen,
/// sin el consentimiento ni el recordatorio (eso es del seguimiento en casa
/// del propio paciente, no de un registro clínico hecho por el fisio).
class _AddPatientScreen extends StatefulWidget {
  const _AddPatientScreen();

  @override
  State<_AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<_AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cedulaController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  Pathology? _pathology;
  BodyView? _affectedSide;

  @override
  void dispose() {
    _cedulaController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || _pathology == null || _affectedSide == null) {
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
    await const PatientRosterService().upsert(profile);
    if (mounted) Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar paciente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _cedulaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cédula'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa la cédula' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del paciente',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Edad'),
              validator: (v) {
                final age = int.tryParse(v?.trim() ?? '');
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
              decoration: InputDecoration(
                labelText: 'Patología',
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
            const SizedBox(height: 20),
            const Text(
              '¿De qué lado presenta la patología?',
              style: TextStyle(
                color: AppColors.darkGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<BodyView>(
              segments: const [
                ButtonSegment(
                  value: BodyView.izquierda,
                  label: Text('Izquierdo'),
                ),
                ButtonSegment(value: BodyView.derecha, label: Text('Derecho')),
              ],
              selected: {?_affectedSide},
              emptySelectionAllowed: true,
              onSelectionChanged: (selection) =>
                  setState(() => _affectedSide = selection.firstOrNull),
            ),
            if (_affectedSide == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Elige un lado',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 28),
            ElevatedButton(onPressed: _save, child: const Text('Agregar')),
          ],
        ),
      ),
    );
  }
}
