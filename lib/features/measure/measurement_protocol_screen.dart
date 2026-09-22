import 'package:flutter/material.dart';

import '../../core/pose/angle_calculator.dart';
import '../../core/pose/body_region.dart';
import '../../core/pose/body_view.dart';
import '../../theme/app_colors.dart';
import 'measure_screen.dart';

/// Distancia/altura de cámara recomendada por ejercicio — ver
/// `patologias_objetivo.docx`, sección "Toma de datos con FisioMetric" de
/// cada patología.
String _cameraDistanceHintFor(String? exerciseId) => switch (exerciseId) {
  'hombro_flexion_sagital' ||
  'hombro_abduccion_frontal' => 'A la altura del pecho, entre 2 y 3 metros de distancia.',
  'codo_flexoextension_sagital' => 'A la altura del codo, a unos 2 metros de distancia.',
  'rodilla_flexoextension_sagital' =>
    'A la altura de la rodilla, entre 1.5 y 2 metros de distancia.',
  _ => 'A 2-3 metros de distancia, que se vea todo el cuerpo en el encuadre.',
};

/// Se muestra justo antes de abrir la cámara para grabar una medición —
/// recuerda las 3 condiciones que más afectan la calidad de la detección
/// de pose: luz, distancia/altura de la cámara, y ropa. Cada una lleva una
/// referencia visual (diagrama o comparación ✓/✗) en vez de ser solo texto
/// — más fácil de captar de un vistazo que un párrafo.
class MeasurementProtocolScreen extends StatelessWidget {
  const MeasurementProtocolScreen({
    super.key,
    required this.initialView,
    required this.patientName,
    this.region = BodyRegion.fullBody,
    this.exerciseId,
    this.trackedJoints,
  });

  final BodyView initialView;
  final String patientName;
  final BodyRegion region;
  final String? exerciseId;
  final Set<JointKind>? trackedJoints;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antes de grabar')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Revisa esto antes de empezar',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Así el sistema detecta mejor tu cuerpo y la medición es más precisa.',
                style: TextStyle(color: AppColors.darkGrey.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _ProtocolSection(
                      icon: Icons.social_distance_outlined,
                      title: 'Distancia de la cámara',
                      child: _DistanceDiagram(hint: _cameraDistanceHintFor(exerciseId)),
                    ),
                    const SizedBox(height: 24),
                    _ProtocolSection(
                      icon: Icons.wb_sunny_outlined,
                      title: 'Iluminación',
                      child: const Row(
                        children: [
                          Expanded(
                            child: _ComparisonCard(
                              good: true,
                              icon: Icons.wb_sunny_outlined,
                              label: 'Luz pareja, de frente',
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _ComparisonCard(
                              good: false,
                              icon: Icons.flare_outlined,
                              label: 'Contraluz (ventana o luz detrás)',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ProtocolSection(
                      icon: Icons.checkroom_outlined,
                      title: 'Ropa',
                      child: const Row(
                        children: [
                          Expanded(
                            child: _ComparisonCard(
                              good: true,
                              icon: Icons.checkroom_outlined,
                              label: 'Ajustada o deportiva',
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _ComparisonCard(
                              good: false,
                              icon: Icons.dry_cleaning_outlined,
                              label: 'Holgada — tapa las articulaciones',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => MeasureScreen(
                      initialView: initialView,
                      region: region,
                      patientName: patientName,
                      exerciseId: exerciseId,
                      trackedJoints: trackedJoints,
                    ),
                  ),
                ),
                child: const Text('Listo, empezar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado (ícono + título) común a las 3 secciones, cada una con su
/// propia referencia visual debajo en vez de un párrafo largo.
class _ProtocolSection extends StatelessWidget {
  const _ProtocolSection({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.tealPrimary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// Diagrama tipo "plano": la silueta guía (mismo asset que la cámara en
/// vivo) a un lado, un ícono de cámara al otro, y una línea punteada con la
/// distancia recomendada en el medio — más claro de un vistazo que
/// describir la distancia solo en palabras.
class _DistanceDiagram extends StatelessWidget {
  const _DistanceDiagram({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.tealPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 90,
            child: Row(
              children: [
                const Icon(Icons.videocam, color: AppColors.darkGrey, size: 30),
                Expanded(
                  child: CustomPaint(painter: _DashedLinePainter()),
                ),
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(AppColors.tealPrimary, BlendMode.srcIn),
                  child: Image.asset('assets/guide/frontal_outline.png', height: 90),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.darkGrey.withValues(alpha: 0.4)
      ..strokeWidth = 2;
    const dash = 6.0;
    const gap = 5.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => false;
}

/// Tarjeta chica "✓ bien" / "✗ evitar" — comparación visual rápida en vez
/// de un párrafo explicando cada condición.
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.good, required this.icon, required this.label});

  final bool good;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = good ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Icon(
            good ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 16,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
