import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../services/patient/patient_profile_service.dart';
import '../../services/storage/session_loader.dart';
import '../../services/storage/session_storage_service.dart';

/// Recordatorio diario tipo Duolingo: si a las [_reminderHour] el paciente
/// registrado todavía no hizo TODAS las mediciones que le tocan hoy (ver
/// `Pathology.exerciseIds` — algunas patologías piden más de una), le
/// llega una notificación del sistema (aparece aunque la app esté cerrada).
///
/// Es 100% local — la app no tiene servidor (ver arquitectura del
/// proyecto), así que no hay forma de "avisar de verdad" si el paciente
/// nunca vuelve a abrir la app: lo que sí se puede hacer, y es lo que hace
/// esta clase, es reprogramar un único recordatorio cada vez que:
/// - se abre la app y se confirma el perfil (PatientGateScreen), o
/// - se termina de guardar una sesión (MeasureScreen).
///
/// Cada llamada a [refresh] decide desde cero cuándo debe sonar el
/// PRÓXIMO recordatorio (hoy a las 8pm si todavía no se ha medido y falta
/// para esa hora; si no, mañana a las 8pm) y reemplaza el que hubiera
/// programado antes — nunca hay más de uno pendiente. Si el paciente deja
/// de abrir la app por varios días, el último recordatorio programado
/// suena en su fecha, un poco desactualizado, pero sigue sirviendo como
/// "vuelve a la app" — no hay forma de hacerlo mejor sin un servidor.
class DailyReminderService {
  DailyReminderService() : _plugin = FlutterLocalNotificationsPlugin();

  static const int _reminderNotificationId = 1001;
  static const int _reminderHour = 20; // 8:00 p.m.

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // `timezone` no puede detectar solo la zona horaria del dispositivo —
    // se arma un nombre `Etc/GMT±N` (parte del tzdata estándar) a partir
    // del offset UTC que sí da `dart:core`, sin depender de una librería
    // aparte. Solo funciona con offsets en horas exactas (sin :30); si el
    // dispositivo tuviera uno de esos casos raros, se usa UTC como
    // respaldo — el recordatorio quedaría corrido esas fracciones de hora,
    // no roto.
    final offset = DateTime.now().timeZoneOffset;
    if (offset.inMinutes % 60 == 0) {
      final sign = offset.isNegative ? '+' : '-';
      tz.setLocalLocation(tz.getLocation('Etc/GMT$sign${offset.abs().inHours}'));
    } else {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );
    _initialized = true;
  }

  Future<bool> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Si el paciente [profile] ya registró hoy TODAS las mediciones que le
  /// tocan (ver `Pathology.exerciseIds`) — no basta con una sola: hombro,
  /// por ejemplo, pide flexión Y abducción, así que hacer solo una de las
  /// dos todavía debería avisar por la que falta.
  Future<bool> _hasDoneTodaysMeasurements(PatientProfile profile) async {
    final all = await loadAllSessions(SessionStorageService());
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;

    final doneExerciseIdsToday = all
        .where((s) => s.metadata.patientName == profile.name && isToday(s.metadata.startedAt))
        .map((s) => s.metadata.exerciseId)
        .whereType<String>()
        .toSet();

    return profile.pathology.exerciseIds.every(doneExerciseIdsToday.contains);
  }

  /// Reprograma el recordatorio para [profile] — llamar al confirmar el
  /// perfil en PatientGateScreen y al terminar de guardar una sesión en
  /// MeasureScreen. Si el paciente niega el permiso de notificaciones, no
  /// hace nada (no se puede programar nada sin él).
  Future<void> refresh(PatientProfile profile) async {
    await _ensureInitialized();
    final granted = await _requestPermission();
    if (!granted) return;

    final doneToday = await _hasDoneTodaysMeasurements(profile);

    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(tz.local, now.year, now.month, now.day, _reminderHour);
    if (doneToday || now.isAfter(target)) {
      target = target.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _reminderNotificationId,
      title: 'Fisiometric',
      body: '¿Ya hiciste tus mediciones de hoy, ${profile.name}? Solo toma un par de minutos.',
      scheduledDate: target,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Recordatorio diario',
          channelDescription: 'Avisa si todavía no hiciste tu medición del día.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
