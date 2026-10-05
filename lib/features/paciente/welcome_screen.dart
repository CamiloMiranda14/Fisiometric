import 'package:flutter/material.dart';

import '../../services/paciente/patient_profile_service.dart';
import '../../tema/app_colors.dart';
import '../home/home_screen.dart';

const _imagenesPasos = [
  (
    ruta: 'assets/tutorial/paso1_ver.png',
    descripcion:
        'Antes de medir, revisa el video del ejercicio que te toca hoy.',
  ),
  (
    ruta: 'assets/tutorial/paso2_grabar.png',
    descripcion:
        'Colócate frente a la cámara y deja que Fisiometric grabe tu movimiento.',
  ),
  (
    ruta: 'assets/tutorial/paso3_importancia.png',
    descripcion:
        'Si usas ropa muy holgada, estás muy lejos o muy cerca, hay poca '
        'luz o el fondo tiene gente moviéndose, el sistema puede perder '
        'de vista tus articulaciones y la medición puede salir mal — '
        'tendrías que repetirla. Por eso, antes de cada grabación, '
        'revisa siempre esos 4 puntos.',
  ),
  (
    ruta: 'assets/tutorial/paso4_progreso.png',
    descripcion:
        'Después de grabar, revisa cómo ha mejorado tu rango de movimiento.',
  ),
];

/// Bienvenida — 5 diapositivas: una de bienvenida (logo + resumen corto) y
/// 4 con fotos del equipo, en este orden: ver el ejercicio, grabar la
/// medición, qué puede salir mal si no se sigue el protocolo de "antes de
/// grabar" (ropa, distancia, luz, fondo) — justo después de la de grabar,
/// porque es la condición para que esa grabación sirva — y por último
/// revisar el progreso. La explicación de CADA sección de la app
/// (medición del día, recomendados, progreso, configuración) no vive acá:
/// la da el recorrido guiado con flechas sobre los botones reales de
/// HomeScreen (ver HomeScreen._mostrarRecorridoGuiado), que es más claro que
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
  static final _slideCount = 1 + _imagenesPasos.length;

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
        builder: (_) => HomeScreen(
          patientProfile: widget.profile,
          mostrarRecorridoGuiado: true,
        ),
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
                  const _DiapositivaBienvenida(),
                  for (final paso in _imagenesPasos)
                    _DiapositivaImagen(
                      ruta: paso.ruta,
                      descripcion: paso.descripcion,
                    ),
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
class _DiapositivaBienvenida extends StatelessWidget {
  const _DiapositivaBienvenida();

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

/// Diapositivas 2 a 5 — una foto por diapositiva (ver ejercicio, grabarlo,
/// el ejemplo de qué sale mal sin el protocolo, y revisar el progreso),
/// con una descripción corta debajo de qué pasa en ese paso.
class _DiapositivaImagen extends StatelessWidget {
  const _DiapositivaImagen({required this.ruta, required this.descripcion});

  final String ruta;
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(ruta, fit: BoxFit.contain),
          ),
          const SizedBox(height: 20),
          Text(
            descripcion,
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
