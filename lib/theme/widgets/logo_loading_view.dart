import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../app_colors.dart';

/// El logo animado de Fisiometric en loop, de fondo blanco (el propio
/// video ya trae ese fondo, así que un fondo blanco alrededor lo hace ver
/// como una sola pieza en vez de una miniatura recuadrada) — usado al
/// inicializar cámara/detector antes de medir (MeasureScreen). Reemplaza
/// el `CircularProgressIndicator` genérico que había ahí antes.
/// PatientGateScreen usa en cambio solo el ícono estático (ver ese
/// archivo) — el perfil carga casi instantáneo, no alcanza a reproducirse
/// nada del video ahí.
class LogoLoadingView extends StatefulWidget {
  const LogoLoadingView({super.key, this.message});

  /// Texto opcional debajo del logo (p.ej. "Iniciando cámara...").
  final String? message;

  @override
  State<LogoLoadingView> createState() => _LogoLoadingViewState();
}

class _LogoLoadingViewState extends State<LogoLoadingView> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/branding/logo_animado.mp4');
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
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Grande de verdad: ocupa casi todo el ancho disponible en vez de
          // una miniatura — la animación es el contenido principal de esta
          // pantalla, no un ícono decorativo.
          final videoWidth = math.min(constraints.maxWidth * 0.96, 600.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: videoWidth,
                child: FutureBuilder<void>(
                  future: _initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox.shrink();
                    }
                    return AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    );
                  },
                ),
              ),
              if (widget.message != null) ...[
                const SizedBox(height: 24),
                Text(
                  widget.message!,
                  style: const TextStyle(color: AppColors.tealPrimary, fontSize: 14),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
