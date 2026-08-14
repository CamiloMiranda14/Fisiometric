import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../theme/app_colors.dart';

enum _GateState { checking, granted, denied, permanentlyDenied }

/// Solo muestra [child] cuando el permiso de cámara está concedido.
/// Mientras tanto, guía al usuario a través de los 3 estados posibles:
/// verificando, denegado (se puede reintentar) y denegado permanentemente
/// (hay que abrir Ajustes).
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key, required this.child});

  final Widget child;

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver {
  _GateState _state = _GateState.checking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El usuario puede conceder el permiso desde Ajustes y volver a la app.
    if (state == AppLifecycleState.resumed && _state != _GateState.granted) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final status = await Permission.camera.status;
    _applyStatus(status);
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    _applyStatus(status);
  }

  void _applyStatus(PermissionStatus status) {
    if (!mounted) return;
    setState(() {
      if (status.isGranted || status.isLimited) {
        _state = _GateState.granted;
      } else if (status.isPermanentlyDenied) {
        _state = _GateState.permanentlyDenied;
      } else {
        _state = _GateState.denied;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _GateState.checking:
        return const _GateScaffold(
          child: CircularProgressIndicator(color: AppColors.orangeAccent),
        );
      case _GateState.granted:
        return widget.child;
      case _GateState.denied:
        return _GateScaffold(
          child: _PermissionMessage(
            icon: Icons.camera_alt_outlined,
            title: 'Fisiometric necesita la cámara',
            message:
                'Para medir los ángulos articulares en tiempo real, Fisiometric '
                'necesita acceso a la cámara del dispositivo.',
            buttonLabel: 'Permitir acceso',
            onPressed: _requestPermission,
          ),
        );
      case _GateState.permanentlyDenied:
        return _GateScaffold(
          child: _PermissionMessage(
            icon: Icons.settings_outlined,
            title: 'Permiso de cámara bloqueado',
            message:
                'Activa el permiso de cámara manualmente en los ajustes del '
                'sistema para poder usar Fisiometric.',
            buttonLabel: 'Abrir ajustes',
            onPressed: openAppSettings,
          ),
        );
    }
  }
}

class _GateScaffold extends StatelessWidget {
  const _GateScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: child),
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.orangeAccent),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}
