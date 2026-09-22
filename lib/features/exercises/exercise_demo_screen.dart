import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/exercise.dart';
import '../../theme/app_colors.dart';
import '../measure/measurement_protocol_screen.dart';

/// Muestra el video de demostración de [exercise] en bucle. El botón
/// "Empezar medición" está disponible en todo momento (no hace falta
/// esperar a que el video termine) y lleva a MeasureScreen ya con la vista
/// (frontal/izquierda/derecha) de este ejercicio preconfigurada.
class ExerciseDemoScreen extends StatefulWidget {
  const ExerciseDemoScreen({
    super.key,
    required this.exercise,
    required this.videoAssetPath,
    required this.patientName,
  });

  /// Ya resuelto por quien navega hasta acá (HomeScreen/ExerciseCatalogScreen)
  /// — su `view` ajustada al lado real del paciente si es sagital.
  final Exercise exercise;

  /// Cuál de los `exercise.videoAssetPaths` mostrar — también resuelto por
  /// quien navega hasta acá, según `PatientProfile.affectedSide`.
  final String videoAssetPath;

  /// Ingresado en PatientGateScreen al abrir la app.
  final String patientName;

  @override
  State<ExerciseDemoScreen> createState() => _ExerciseDemoScreenState();
}

class _ExerciseDemoScreenState extends State<ExerciseDemoScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoAssetPath);
    _initFuture = _controller.initialize().then((_) {
      _controller
        ..setLooping(true)
        ..play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startMeasurement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeasurementProtocolScreen(
          initialView: widget.exercise.view,
          region: widget.exercise.region,
          patientName: widget.patientName,
          exerciseId: widget.exercise.id,
          trackedJoints: widget.exercise.trackedJoints,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FutureBuilder<void>(
                  future: _initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const CircularProgressIndicator(
                        color: AppColors.orangeAccent,
                      );
                    }
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No se pudo cargar el video de demostración de este '
                          'ejercicio. Puedes igual empezar la medición.',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: _startMeasurement,
                child: const Text('Empezar medición'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
