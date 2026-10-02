import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/ejercicios/exercise_catalog.dart';
import '../almacenamiento/session_loader.dart';
import '../almacenamiento/session_storage_service.dart';
import '../paciente/patient_profile_service.dart';

/// Recordatorio diario tipo Duolingo: avisa al paciente si todavía no ha
/// hecho la medición que le toca hoy.
///
/// RESUMEN: a partir de la hora que el paciente eligió (ver
/// PatientGateScreen), si todavía le falta algo por medir hoy, se programa
/// un aviso que se repite cada 30 minutos hasta las 11pm — así una sesión
/// olvidada o a medias sigue recordándose, no solo una vez. Cada vez que
/// se guarda una medición o se reabre la app se llama a [refresh], que
/// recalcula y REEMPLAZA toda la serie del día desde cero: en cuanto el
/// paciente completa lo que le tocaba, los avisos que quedaban se
/// cancelan solos. Es 100% local (notificaciones del sistema operativo,
/// sin servidor), así que esto es lo más parecido a "avisar de verdad"
/// que se puede hacer sin uno.
class DailyReminderService {
  // SINGLETON a propósito: el manejador de toques de notificación se
  // registra una sola vez en main() (ver [ensureInitialized]), antes de
  // que se arme cualquier pantalla — con una instancia nueva cada vez,
  // ese registro se perdería.
  factory DailyReminderService() => _instance;

  DailyReminderService._internal() : _plugin = FlutterLocalNotificationsPlugin();

  static final DailyReminderService _instance = DailyReminderService._internal();

  static const int _testNotificationId = 1002;

  /// IDs `_reminderBaseId`..`_reminderBaseId + _maxReminderSlots - 1`: un
  /// "pool" fijo de IDs para la serie de avisos cada 30 min del día (ver
  /// [refresh]). 48 alcanza de sobra: el caso más largo posible es elegir
  /// la hora 00:00 y repetir cada 30 min hasta las 11pm, 47 avisos.
  static const int _reminderBaseId = 2000;
  static const int _maxReminderSlots = 48;
  static const String _openActionId = 'open_app';

  /// Hora en que para la serie de avisos del día — pasada esta hora no se
  /// programa nada más hasta la hora elegida del día siguiente.
  static const int _seriesEndHour = 23;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  String? _largeIconPath;

  /// Registra el plugin de notificaciones — se llama una sola vez, lo
  /// antes posible (ver `main.dart`), ANTES de pedir ningún permiso (eso
  /// pasa después, ver [requestPermission]/[refresh]).
  Future<void> ensureInitialized() => _ensureInitialized();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    // zona horaria del dispositivo
    final offset = DateTime.now().timeZoneOffset;
    if (offset.inMinutes % 60 == 0) {
      final sign = offset.isNegative ? '+' : '-';
      tz.setLocalLocation(tz.getLocation('Etc/GMT$sign${offset.abs().inHours}'));
    } else {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('ic_stat_fisiometric');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (_) {}, // Abrir app: Android ya lo hace solo al tocar.
    );
    _initialized = true;
  }

  Future<bool> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Solo CONSULTA si el permiso de "alarmas y recordatorios" (Android 12+)
  /// ya está concedido, sin pedirlo ni abrir Ajustes. Se usa en cada
  /// [refresh] (que se llama muy seguido: al reabrir la app, al confirmar
  /// perfil, al guardar sesión) para decidir el modo de entrega: sin este
  /// permiso, `zonedSchedule` solo puede pedir una entrega APROXIMADA
  /// (`inexactAllowWhileIdle`), que el ahorro de batería puede retrasar por
  /// horas o saltarse por completo; con el permiso, se agenda en modo
  /// exacto (`exactAllowWhileIdle`), que sí suena a la hora elegida.
  Future<bool> _hasExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  /// Pide el permiso de notificaciones (si el sistema operativo todavía no
  /// lo había preguntado, muestra el diálogo nativo) — expuesto aparte de
  /// [refresh] para que PatientGateScreen pueda saber si quedó concedido
  /// ANTES de mostrarle al paciente el selector de hora.
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    return _requestPermission();
  }

  /// Pide el permiso de "alarmas y recordatorios" — a diferencia de
  /// [_hasExactAlarmPermission], SÍ puede abrir la pantalla de Ajustes del
  /// sistema si todavía no está concedido, así que solo se llama una vez,
  /// junto con [requestPermission] cuando el paciente configura su
  /// recordatorio por primera vez (ver PatientGateScreen), nunca desde
  /// [refresh], para no sacar al paciente de la app cada vez que la abre.
  Future<bool> requestExactAlarmPermission() async {
    await _ensureInitialized();
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestExactAlarmsPermission() ?? false;
  }

  /// Ruta del logo de la app ya copiado a un archivo — se usa como imagen
  /// grande de la notificación (`largeIcon`). `flutter_local_notifications`
  /// no puede leer un asset de Flutter directamente ahí, solo un archivo o
  /// un recurso nativo de Android, así que hay que copiarlo primero.
  Future<String> _ensureLargeIcon() async {
    final cached = _largeIconPath;
    if (cached != null) return cached;

    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/notification_logo.png');
    final data = await rootBundle.load('assets/icon/notification_large_icon.png');
    await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    _largeIconPath = file.path;
    return file.path;
  }

  Future<NotificationDetails> _notificationDetails() async {
    final iconPath = await _ensureLargeIcon();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        'Recordatorio diario',
        channelDescription: 'Avisa si todavía no hiciste tu medición del día.',
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: FilePathAndroidBitmap(iconPath),
        actions: const [
          AndroidNotificationAction(_openActionId, 'Abrir app', showsUserInterface: true),
        ],
      ),
    );
  }

  /// "Buenos días"/"Buenas tardes"/"Buenas noches" según la hora de [at] —
  /// para que el saludo de la notificación tenga sentido sin importar a
  /// qué hora suene.
  String _greetingFor(DateTime at) {
    final hour = at.hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// `Exercise.id` de `Pathology.exerciseIds` que [profile] todavía NO
  /// registró hoy — vacío si ya hizo todas. Sirve tanto para decidir SI
  /// avisar (¿hay algo pendiente?) como para armar el mensaje, que
  /// distingue "no hizo ninguna" de "le falta una".
  Future<List<String>> _missingExerciseIdsToday(PatientProfile profile) async {
    final all = await loadAllSessions(SessionStorageService());

    // filtro diario del paciente: qué ejercicios ya tienen sesión hoy
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    final doneIdsToday = all
        .where((s) => s.metadata.patientName == profile.name && isToday(s.metadata.startedAt))
        .map((s) => s.metadata.exerciseId)
        .whereType<String>()
        .toSet();

    return profile.pathology.exerciseIds.where((id) => !doneIdsToday.contains(id)).toList();
  }

  /// Cancela toda la serie de avisos del día (el pool completo de IDs, ver
  /// [_reminderBaseId]) sin programar nada nuevo — usado cuando el paciente
  /// desactiva las notificaciones desde SettingsScreen, o como el primer
  /// paso de [refresh] antes de reprogramar desde cero.
  Future<void> _cancelScheduled() async {
    await _ensureInitialized();
    for (var i = 0; i < _maxReminderSlots; i++) {
      await _plugin.cancel(id: _reminderBaseId + i);
    }
  }

  /// Reprograma toda la serie de avisos del día — llamar al confirmar el
  /// perfil en PatientGateScreen y al terminar de guardar una sesión en
  /// MeasureScreen.
  Future<void> refresh(PatientProfile profile) async {
    await _ensureInitialized();

    await _cancelScheduled();

    if (!profile.notificationsEnabled) return;
    final granted = await _requestPermission();
    if (!granted) return;

    final missingToday = await _missingExerciseIdsToday(profile);
    final doneToday = missingToday.isEmpty;
    final details = await _notificationDetails();
    final scheduleMode = await _hasExactAlarmPermission()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    // hora del primer aviso
    final now = tz.TZDateTime.now(tz.local);
    var firstSlot = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      profile.reminderHour,
      profile.reminderMinute,
    );
    if (doneToday || now.isAfter(firstSlot)) {
      firstSlot = firstSlot.add(const Duration(days: 1));
    }

    final endOfSeries = tz.TZDateTime(
      tz.local,
      firstSlot.year,
      firstSlot.month,
      firstSlot.day,
      _seriesEndHour,
    );

    // armar el mensaje
    final missingNames = missingToday.map((id) => exerciseForId(id)?.name ?? id).toList();
    final allMissing = missingNames.length == profile.pathology.exerciseIds.length;
    final body = missingNames.isEmpty
        // Se programa igual para "mañana" (caso doneToday) sin saber
        // todavía qué le va a faltar ese día — se corrige solo la próxima
        // vez que se llame a refresh() antes de que suene.
        ? 'No has hecho tu medición de hoy, solo toma un par de minutos.'
        : allMissing
        ? 'No has hecho tu medición de hoy, todavía alcanzas a hacerla, '
              'aunque sea rápido pero bien hecha.'
        : 'Te falta "${missingNames.join(', ')}" en tu sesión de hoy, '
              'todavía alcanzas a hacerla.';

    // un aviso cada 30 minutos
    var slot = firstSlot;
    var index = 0;
    while (index < _maxReminderSlots && (index == 0 || !slot.isAfter(endOfSeries))) {
      await _plugin.zonedSchedule(
        id: _reminderBaseId + index,
        title: '${_greetingFor(slot)}, ${profile.name}',
        body: body,
        scheduledDate: slot,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
      );
      slot = slot.add(const Duration(minutes: 30));
      index++;
    }
  }

  /// Manda la notificación YA, sin esperar a la hora programada — para
  /// poder ver cómo se ve/confirmar que sí llega, en vez de tener que
  /// esperar hasta la hora elegida cada vez que se quiera probar.
  Future<void> sendTestNotification(String patientName) async {
    await _ensureInitialized();
    final granted = await _requestPermission();
    if (!granted) return;

    final now = DateTime.now();
    await _plugin.show(
      id: _testNotificationId,
      title: '${_greetingFor(now)}, $patientName',
      body: 'No has hecho tu medición de hoy, solo toma un par de minutos.',
      notificationDetails: await _notificationDetails(),
    );
  }
}
