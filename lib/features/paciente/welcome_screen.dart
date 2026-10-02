import 'package:flutter/material.dart';

import '../../services/paciente/patient_profile_service.dart';
import '../../tema/app_colors.dart';
import '../home/home_screen.dart';

const _stepImages = [
  (
    path: 'assets/onboarding/paso1_ver.png',
    caption: 'Antes de medir, revisa el video del ejercicio que te toca hoy.',
  ),
  (
    path: 'assets/onboarding/paso2_grabar.png',
    caption:
        'Colócate frente a la cámara y deja que Fisiometric grabe tu movimiento.',
  ),
  (
    path: 'assets/onboarding/paso3_progreso.png',
    caption:
        'Después de grabar, revisa cómo ha mejorado tu rango de movimiento.',
  ),
];

/// Bienvenida — 4 diapositivas: una de bienvenida (logo + resumen corto) y
/// 3 con las fotos del equipo (ver ejercicio, grabarlo, revisar el
/// progreso), una por una. La explicación de CADA sección de la app
/// (medición del día, recomendados, progreso, configuración) no vive acá:
/// la da el recorrido guiado con flechas sobre los botones reales de
/// HomeScreen (ver HomeScreen._showCoachMarks), que es más claro que
/// explicarlo aparte de la app de verdad.
///
/// Se muestra una sola vez por cédula nueva, justo después de aceptar el
/// consentimiento informado y conceder los permisos. También se puede
/// volver a ver desde Configuración (ver SettingsScreen), mientras el
/// equipo todavía está probando cómo se ve.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.profile});

  final PatientProfile profile;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static final _slideCount = 1 + _stepImages.length;

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            HomeScreen(patientProfile: widget.profile, showCoachMarks: true),
      ),
      (route) => false,
    );
  }

  void _next() {
    if (_page == _slideCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slideCount - 1;
    return Scaffold(
      backgroundColor: AppColors.tealPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  'Omitir',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _WelcomeSlide(),
                  for (final step in _stepImages)
                    _ImageSlide(path: step.path, caption: step.caption),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slideCount; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: i == _page ? 1 : 0.4,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.tealPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _next,
                  child: Text(isLast ? 'Empezar' : 'Siguiente'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diapositiva 1 — logo, título y resumen corto de qué hace la app.
class _WelcomeSlide extends StatelessWidget {
  const _WelcomeSlide();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset('assets/icon/icon.png', width: 96, height: 96),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '¡Bienvenido a Fisiometric!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Mide tu rango de movimiento con la cámara de tu celular, sin '
            'equipos especiales: solo te paras frente a la cámara y sigues '
            'la guía en pantalla.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diapositivas 2 a 4 — una foto del equipo por diapositiva (ver ejercicio,
/// grabarlo, revisar el progreso), con una descripción corta debajo de qué
/// pasa en ese paso.
class _ImageSlide extends StatelessWidget {
  const _ImageSlide({required this.path, required this.caption});

  final String path;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(path, fit: BoxFit.contain),
          ),
          const SizedBox(height: 20),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
