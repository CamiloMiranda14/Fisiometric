import 'package:flutter/material.dart';

import 'features/patient/patient_gate_screen.dart';
import 'theme/app_theme.dart';

class FisiometricApp extends StatelessWidget {
  const FisiometricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fisiometric',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const PatientGateScreen(),
    );
  }
}
