import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/recommended_exercise.dart';
import '../../theme/app_colors.dart';

/// Muestra el video de un ejercicio terapéutico recomendado, grabado por un
/// profesional — a diferencia de ExerciseDemoScreen, acá no hay "Empezar
/// medición": este ejercicio no se graba ni se evalúa, el paciente solo lo
/// mira para repetirlo por su cuenta.
class RecommendedExerciseScreen extends StatefulWidget {
  const RecommendedExerciseScreen({super.key, required this.exercise});

  final RecommendedExercise exercise;

  @override
  State<RecommendedExerciseScreen> createState() => _RecommendedExerciseScreenState();
}

class _RecommendedExerciseScreenState extends State<RecommendedExerciseScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.exercise.videoAssetPath);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ColoredBox(
                color: Colors.black,
                child: FutureBuilder<void>(
                  future: _initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.orangeAccent),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Todavía no se cargó el video de demostración de '
                            'este ejercicio.',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.tealPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Ejercicio recomendado — no se graba ni se evalúa',
                        style: TextStyle(color: AppColors.tealPrimary, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.exercise.description,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
