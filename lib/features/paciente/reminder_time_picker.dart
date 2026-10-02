import 'package:flutter/material.dart';

import '../../services/notificaciones/daily_reminder_service.dart';
import '../../services/paciente/patient_profile_service.dart';

/// Abre el selector de hora nativo, guarda la elección en el perfil y
/// reprograma el recordatorio diario con la nueva hora — compartido entre
/// PatientGateScreen (la primera vez que se abre la app, justo después de
/// aceptar el permiso de notificaciones) y el menú de HomeScreen (para
/// cambiarla después, cuando el paciente quiera).
///
/// Devuelve el perfil ya actualizado y guardado, o `null` si el paciente
/// cerró el selector sin elegir nada (en ese caso no se toca el perfil).
Future<PatientProfile?> pickAndSaveReminderTime(
  BuildContext context,
  PatientProfile profile,
) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: profile.reminderHour,
      minute: profile.reminderMinute,
    ),
    helpText: 'Hora del recordatorio diario',
  );
  if (picked == null || !context.mounted) return null;

  final updated = profile.copyWith(
    reminderHour: picked.hour,
    reminderMinute: picked.minute,
  );
  await const PatientProfileService().save(updated);
  await DailyReminderService().refresh(updated);
  return updated;
}
