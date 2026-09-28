import 'package:flutter/material.dart';

import '../../core/pose/body_view.dart';
import '../../models/pathology.dart';
import '../../services/notifications/daily_reminder_service.dart';
import '../../services/patient/patient_profile_service.dart';
import '../../theme/app_colors.dart';
import 'reminder_time_picker.dart';

/// Todo lo que no es "medir hoy": notificaciones, datos personales del
/// paciente y el aviso de consentimiento/almacenamiento de datos — antes
/// repartido entre el menú de HomeScreen (recordatorio) y ningún lado
/// (datos personales no se podían editar después de PatientGateScreen).
/// Devuelve el perfil actualizado a quien la abrió (HomeScreen) para que
/// refresque su estado, o `null` si no cambió nada.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.profile});

  final PatientProfile profile;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late PatientProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  Future<void> _save(PatientProfile updated) async {
    await const PatientProfileService().save(updated);
    setState(() => _profile = updated);
  }

  Future<void> _toggleNotifications(bool enabled) async {
    final updated = _profile.copyWith(notificationsEnabled: enabled);
    await _save(updated);
    await DailyReminderService().refresh(updated);
  }

  Future<void> _changeReminderTime() async {
    final updated = await pickAndSaveReminderTime(context, _profile);
    if (updated != null) setState(() => _profile = updated);
  }

  Future<void> _sendTestNotification() async {
    await DailyReminderService().sendTestNotification(_profile.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notificación de prueba enviada, revisa la barra de notificaciones.',
        ),
      ),
    );
  }

  Future<void> _editPersonalData() async {
    final updated = await Navigator.of(context).push<PatientProfile>(
      MaterialPageRoute(builder: (_) => _PersonalDataScreen(profile: _profile)),
    );
    if (updated == null) return;
    await _save(updated);
    await DailyReminderService().refresh(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader('Notificaciones'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Permitir notificaciones'),
            subtitle: const Text(
              'Recordatorio diario si todavía no te has medido.',
            ),
            value: _profile.notificationsEnabled,
            onChanged: _toggleNotifications,
          ),
          ListTile(
            enabled: _profile.notificationsEnabled,
            leading: const Icon(Icons.access_time_outlined),
            title: const Text('Hora del recordatorio'),
            subtitle: Text(
              TimeOfDay(
                hour: _profile.reminderHour,
                minute: _profile.reminderMinute,
              ).format(context),
            ),
            onTap: _changeReminderTime,
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('Probar notificación'),
            subtitle: const Text('Manda un aviso de prueba ya mismo.'),
            onTap: _sendTestNotification,
          ),
          const Divider(height: 32),
          _SectionHeader('Datos personales'),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Nombre, cédula, edad y patología'),
            subtitle: Text('${_profile.name} · ${_profile.pathology.label}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editPersonalData,
          ),
          const Divider(height: 32),
          _SectionHeader('Privacidad y almacenamiento de datos'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _ConsentInfoCard(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: AppColors.tealPrimary,
        ),
      ),
    );
  }
}

/// Resumen de consentimiento y almacenamiento, pensado para ajustar el
/// texto legal definitivo del equipo más adelante sin tocar la estructura
/// de la pantalla. Mientras los datos se guardan solo en este dispositivo,
/// se avisa eso explícitamente: la migración a un almacenamiento en la nube
/// (Firebase, ya planeada por el equipo) es lo que va a evitar que se
/// pierdan si se desinstala la app, pero todavía no está implementada.
class _ConsentInfoCard extends StatelessWidget {
  const _ConsentInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tealPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.tealPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Consentimiento informado',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Al usar Fisiometric aceptaste el consentimiento informado del '
            'estudio: tus videos y mediciones se usan únicamente con fines '
            'de seguimiento clínico e investigación, y no se comparten con '
            'terceros sin tu autorización.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(
                Icons.storage_outlined,
                color: AppColors.tealPrimary,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dónde se guardan tus datos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Por ahora, tus videos y mediciones se guardan solo en este '
            'celular, así que se pierden si desinstalas la app. Estamos '
            'trabajando en sincronizarlos con un almacenamiento en la nube '
            '(Firebase) para que queden respaldados aunque cambies o '
            'desinstales la app.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Formulario para editar los datos ingresados la primera vez en
/// PatientGateScreen — separado de SettingsScreen para no mezclar "ver
/// configuración" con "editar un formulario largo". Devuelve el perfil
/// actualizado (sin guardarlo todavía, lo hace SettingsScreen) o `null` si
/// se cancela.
class _PersonalDataScreen extends StatefulWidget {
  const _PersonalDataScreen({required this.profile});

  final PatientProfile profile;

  @override
  State<_PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<_PersonalDataScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cedulaController;
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late Pathology _pathology;
  late BodyView _affectedSide;

  @override
  void initState() {
    super.initState();
    _cedulaController = TextEditingController(text: widget.profile.cedula);
    _nameController = TextEditingController(text: widget.profile.name);
    _ageController = TextEditingController(text: '${widget.profile.age}');
    _pathology = widget.profile.pathology;
    _affectedSide = widget.profile.affectedSide;
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      widget.profile.copyWith(
        cedula: _cedulaController.text.trim(),
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        pathology: _pathology,
        affectedSide: _affectedSide,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos personales')),
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
              decoration: const InputDecoration(labelText: 'Patología'),
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
              onChanged: (value) {
                if (value != null) setState(() => _pathology = value);
              },
            ),
            const SizedBox(height: 20),
            const Text(
              '¿De qué lado presentas la patología?',
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
              selected: {_affectedSide},
              onSelectionChanged: (selection) =>
                  setState(() => _affectedSide = selection.first),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
