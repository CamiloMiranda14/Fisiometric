import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/exercises/exercise_catalog.dart';
import '../../services/patient/patient_profile_service.dart';
import '../../services/storage/session_loader.dart';
import '../../services/storage/session_storage_service.dart';

/// Recordatorio diario tipo Duolingo — dos avisos independientes, cada uno
/// programado por separado:
///
/// 1. **El elegido por el paciente** (`profile.reminderHour`/`.reminderMinute`
///    — personalizable, ver PatientGateScreen), si a esa hora todavía no
///    hizo TODAS las mediciones que le tocan hoy.
/// 2. **Última llamada, siempre a las 11pm**, sin importar si el aviso de
///    arriba ya sonó antes — si a esa hora sigue sin terminar, es la
///    última oportunidad del día. El mensaje distingue si no hizo NINGUNA
///    medición ("recuerda hacerla") de si le falta solo una de las dos que
///    pide su patología (hombro/cadera piden flexión Y abducción) —
///    "te falta X".
///
/// Ambos avisos aparecen aunque la app esté cerrada (son notificaciones del
/// sistema operativo, no algo que dependa de que la app siga corriendo).
///
/// Es 100% local — la app no tiene servidor (ver arquitectura del
/// proyecto), así que no hay forma de "avisar de verdad" si el paciente
/// nunca vuelve a abrir la app: lo que sí se puede hacer, y es lo que hace
/// esta clase, es reprogramar los dos avisos cada vez que:
/// - se abre la app y se confirma el perfil (PatientGateScreen), o
/// - se termina de guardar una sesión (MeasureScreen).
///
/// Cada llamada a [refresh] decide desde cero cuándo debe sonar el
/// PRÓXIMO de cada uno (hoy si todavía falta tiempo y no se ha completado
/// todo; si no, mañana a esa misma hora) y reemplaza el que hubiera
/// programado antes — nunca hay más de uno pendiente de cada tipo. Si el
/// paciente deja de abrir la app por varios días, el último recordatorio
/// programado suena en su fecha, un poco desactualizado, pero sigue
/// sirviendo como "vuelve a la app" — no hay forma de hacerlo mejor sin un
/// servidor.
///
/// SINGLETON a propósito (antes se creaba una instancia nueva cada vez, sin
/// que importara porque no guardaba estado propio) — ahora sí importa: el
/// manejador de toques se registra una sola vez en `main()` (ver
/// [ensureInitialized]), antes de que se arme cualquier pantalla.
class DailyReminderService {
  factory DailyReminderService() => _instance;

  DailyReminderService._internal() : _plugin = FlutterLocalNotificationsPlugin();

  static final DailyReminderService _instance = DailyReminderService._internal();

  static const int _reminderNotificationId = 1001;
  static const int _testNotificationId = 1002;
  static const int _lastCallNotificationId = 1003;
  static const String _openActionId = 'open_app';

  /// Hora fija de la "última llamada" — independiente de la hora que el
  /// paciente eligió para su recordatorio principal.
  static const int _lastCallHour = 23;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  String? _largeIconPath;

  /// Registra el plugin (incluye el manejador de toques) — se llama una
  /// sola vez, lo antes posible (ver `main.dart`), ANTES de pedir ningún
  /// permiso: eso sigue pasando después, cuando corresponda (ver
  /// [requestPermission]/[refresh]).
  Future<void> ensureInitialized() => _ensureInitialized();

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

    // Ícono pequeño (la barra de estado): tiene que ser un dibujo BLANCO
    // sobre fondo transparente — Android lo exige así desde Lollipop y
    // descarta cualquier color, así que usar el logo a color ahí (como
    // pasaba antes con `@mipmap/ic_launcher`) se veía como un cuadrado
    // vacío. `ic_stat_fisiometric` es la silueta blanca generada a partir
    // del logo, puesta en `android/app/src/main/res/drawable-*`.
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
  /// ya está concedido — sin pedirlo ni abrir Ajustes. Se usa en cada
  /// [refresh] (que se llama muy seguido: al reabrir la app, al confirmar
  /// perfil, al guardar sesión) para decidir el modo de entrega: sin este
  /// permiso, `zonedSchedule` solo puede pedir una entrega APROXIMADA
  /// (`inexactAllowWhileIdle`), que el ahorro de batería puede retrasar por
  /// horas o saltarse por completo — con el permiso, se agenda en modo
  /// exacto (`exactAllowWhileIdle`), que sí suena a la hora elegida.
  Future<bool> _hasExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  /// Pide el permiso de notificaciones (si el sistema operativo todavía no
  /// lo había preguntado, muestra el diálogo nativo) — expuesto aparte de
  /// [refresh] para que PatientGateScreen pueda saber si quedó concedido
  /// ANTES de mostrarle al paciente el selector de hora (no tiene sentido
  /// dejarlo elegir una hora si de todas formas no va a poder recibir nada).
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    return _requestPermission();
  }

  /// Pide el permiso de "alarmas y recordatorios" — a diferencia de
  /// [_hasExactAlarmPermission], SÍ puede abrir la pantalla de Ajustes del
  /// sistema si todavía no está concedido, así que solo se llama una vez,
  /// junto con [requestPermission] cuando el paciente configura su
  /// recordatorio por primera vez (ver PatientGateScreen) — nunca desde
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
  /// un recurso nativo de Android; se copia una sola vez (se cachea la
  /// ruta) en vez de en cada notificación.
  Future<String> _ensureLargeIcon() async {
    final cached = _largeIconPath;
    if (cached != null) return cached;

    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/notification_logo.png');
    // Se reescribe siempre (no solo si falta) para que una actualización de
    // la app con un logo nuevo no se quede pegada al archivo viejo que ya
    // estaba copiado en el dispositivo — el costo es mínimo (un archivo
    // chico, una sola vez por sesión de la app).
    final data = await rootBundle.load('assets/icon/icon.png');
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

  String _greetingFor(DateTime at) {
    final hour = at.hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// `Exercise.id` de `Pathology.exerciseIds` que [profile] todavía NO
  /// registró hoy — vacío si ya hizo todas. Sirve tanto para decidir SI
  /// avisar (¿hay algo pendiente?) como para el mensaje de la última
  /// llamada, que distingue "no hizo ninguna" de "le falta una".
  Future<List<String>> _missingExerciseIdsToday(PatientProfile profile) async {
    final all = await loadAllSessions(SessionStorageService());
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

  /// Cancela los dos avisos programados (el elegido por el paciente y la
  /// última llamada) sin programar nada nuevo — usado cuando el paciente
  /// desactiva las notificaciones desde SettingsScreen, o como el primer
  /// paso de [refresh] antes de reprogramar.
  Future<void> _cancelScheduled() async {
    await _ensureInitialized();
    await _plugin.cancel(id: _reminderNotificationId);
    await _plugin.cancel(id: _lastCallNotificationId);
  }

  /// Reprograma AMBOS avisos (el elegido por el paciente y la última
  /// llamada de las 11pm) — llamar al confirmar el perfil en
  /// PatientGateScreen y al terminar de guardar una sesión en
  /// MeasureScreen. Si el paciente niega el permiso de notificaciones, o
  /// las desactivó desde SettingsScreen (`profile.notificationsEnabled`),
  /// cancela lo que hubiera pendiente y no programa nada nuevo.
  Future<void> refresh(PatientProfile profile) async {
    await _ensureInitialized();
    if (!profile.notificationsEnabled) {
      await _cancelScheduled();
      return;
    }
    final granted = await _requestPermission();
    if (!granted) return;

    final missingToday = await _missingExerciseIdsToday(profile);
    final doneToday = missingToday.isEmpty;
    final details = await _notificationDetails();
    final scheduleMode = await _hasExactAlarmPermission()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    // 1) El recordatorio a la hora que eligió el paciente.
    final now = tz.TZDateTime.now(tz.local);
    var chosenTarget = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      profile.reminderHour,
      profile.reminderMinute,
    );
    if (doneToday || now.isAfter(chosenTarget)) {
      chosenTarget = chosenTarget.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: _reminderNotificationId,
      title: '${_greetingFor(chosenTarget)}, ${profile.name}',
      body: 'No has hecho tu medición de hoy, solo toma un par de minutos.',
      scheduledDate: chosenTarget,
      notificationDetails: details,
      androidScheduleMode: scheduleMode,
    );

    // 2) La última llamada, siempre a las 11pm — independiente de si el
    // aviso de arriba ya sonó hoy. Si la hora elegida por el paciente ya
    // es 11pm o más tarde, no tiene sentido duplicarlo.
    if (profile.reminderHour >= _lastCallHour) return;

    var lastCallTarget = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _lastCallHour,
    );
    if (doneToday || now.isAfter(lastCallTarget)) {
      lastCallTarget = lastCallTarget.add(const Duration(days: 1));
    }
    final missingNames = missingToday
        .map((id) => exerciseForId(id)?.name ?? id)
        .toList();
    final allMissing = missingNames.length == profile.pathology.exerciseIds.length;
    final lastCallBody = missingNames.isEmpty
        // Se programa igual para "mañana" (caso doneToday) sin saber
        // todavía qué le va a faltar ese día — se corrige solo la próxima
        // vez que se llame a refresh() antes de que suene.
        ? 'No has hecho tu medición de hoy, ya casi se acaba el día, hazla '
              'aunque sea rápido, pero bien hecha.'
        : allMissing
        ? 'Ya casi se acaba el día y no has hecho tu medición de hoy, '
              'todavía alcanzas a hacerla, aunque sea rápido, pero bien hecha.'
        : 'Ya casi se acaba el día y te falta "${missingNames.join(', ')}" en '
              'tu sesión de hoy, todavía alcanzas a hacerla.';

    await _plugin.zonedSchedule(
      id: _lastCallNotificationId,
      title: '${_greetingFor(lastCallTarget)}, ${profile.name}',
      body: lastCallBody,
      scheduledDate: lastCallTarget,
      notificationDetails: details,
      androidScheduleMode: scheduleMode,
    );
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
