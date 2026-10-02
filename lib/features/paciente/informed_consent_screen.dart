import 'package:flutter/material.dart';

import '../../core/utilidades/session_naming.dart';
import '../../services/consentimiento/consent_service.dart';
import '../../services/paciente/patient_profile_service.dart';
import '../../tema/app_colors.dart';

/// Consentimiento informado del estudio — se muestra una sola vez por
/// cédula nueva (ver ConsentService), antes de dejar entrar a la app. El
/// texto legal es el mismo que el documento en papel del equipo, con sus
/// espacios en blanco ya resueltos: nombre/cédula vienen del perfil recién
/// llenado en PatientGateScreen, y la ciudad de expedición se pide acá
/// mismo (es el único dato de este documento que el resto de la app no usa
/// para nada más).
///
/// La "firma" es digital: la persona vuelve a escribir su nombre completo
/// como gesto explícito de aceptación, junto con el botón "Acepto y
/// continúo" — equivalente a firmar, sin necesitar una librería de dibujo.
///
/// Devuelve `true` si aceptó (y ya quedó guardado en ConsentService),
/// `false`/`null` si no.
class InformedConsentScreen extends StatefulWidget {
  const InformedConsentScreen({super.key, required this.profile});

  final PatientProfile profile;

  @override
  State<InformedConsentScreen> createState() => _InformedConsentScreenState();
}

class _InformedConsentScreenState extends State<InformedConsentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  late final TextEditingController _signatureController;

  @override
  void initState() {
    super.initState();
    _signatureController = TextEditingController(text: widget.profile.name);
  }

  @override
  void dispose() {
    _cityController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await const ConsentService().recordConsent(
      cedula: widget.profile.cedula,
      signedName: _signatureController.text.trim(),
      cedulaIssuedCity: _cityController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Seguro que no aceptas?'),
        content: const Text(
          'Sin aceptar el consentimiento informado no puedes usar '
          'Fisiometric para registrar mediciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'No aceptar',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return PopScope(
      canPop: false,
      // El botón atrás del sistema cuenta como "no acepto" (con la misma
      // confirmación) — no se puede saltar el consentimiento sin decidir.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _reject();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Consentimiento informado')),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.tealPrimary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: AppColors.darkGrey,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'Yo, '),
                            TextSpan(
                              text: profile.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  ', identificado con cédula de ciudadanía número ',
                            ),
                            TextSpan(
                              text: profile.cedula,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' de '),
                            TextSpan(
                              text: _cityController.text.trim().isEmpty
                                  ? '___________'
                                  : _cityController.text.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  ' he leído y comprendido la información anterior y mis '
                                  'preguntas han sido respondidas de manera satisfactoria. '
                                  'Me han indicado que participaré en sesiones de captura '
                                  'de movimiento mediante la cámara de un smartphone, '
                                  'ejecutando ejercicios terapéuticos de miembro superior '
                                  'o inferior, con el fin de validar el sistema FisioMetric '
                                  'de análisis biomecánico asistido por inteligencia '
                                  'artificial. Reconozco que la información personal que yo '
                                  'provea en el curso de esta investigación no se publicará '
                                  'ni será usada para ningún otro propósito fuera de los de '
                                  'este estudio sin mi consentimiento, por el contrario, el '
                                  'manejo de los datos sensibles será estrictamente '
                                  'confidencial y estará bajo el cuidado y manejo de los '
                                  'investigadores encargados. Además, he sido informado que '
                                  'puedo hacer preguntas sobre el proyecto en cualquier '
                                  'momento y que puedo retirarme del mismo cuando así lo '
                                  'decida, sin que esto me acarree perjuicio alguno.\n\n'
                                  'Acepto participar voluntariamente en esta investigación.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Ciudad de expedición de tu cédula',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa la ciudad'
                          : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _signatureController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Firma (escribe tu nombre completo)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Escribe tu nombre completo'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Fecha: ${formatDateWords(DateTime.now())}',
                        style: TextStyle(
                          color: AppColors.darkGrey.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _reject,
                          child: const Text('No acepto'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _accept,
                          child: const Text('Acepto y continúo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
