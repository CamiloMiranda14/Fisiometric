import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../modelos/exercise.dart';
import '../../modelos/recommended_exercise.dart';
import '../../services/notificaciones/daily_reminder_service.dart';
import '../../services/paciente/patient_profile_service.dart';
import '../../services/almacenamiento/session_loader.dart';
import '../../services/almacenamiento/session_storage_service.dart';
import '../../tema/app_colors.dart';
import '../ejercicios/exercise_catalog.dart';
import '../ejercicios/exercise_catalog_screen.dart';
import '../ejercicios/exercise_demo_screen.dart';
import '../ejercicios/recommended_exercise_catalog.dart';
import '../ejercicios/recommended_exercise_catalog_screen.dart';
import '../ejercicios/recommended_exercise_screen.dart';
import '../paciente/settings_screen.dart';
import '../progreso/progress_screen.dart';
import '../sesiones/sessions_list_screen.dart';
import 'quick_test_view_screen.dart';

/// Ítems que no son específicos de este paciente/patología — quedan detrás
/// del ícono de menú en vez de ocupar espacio en la pantalla principal,
/// para que esa pantalla quede especializada solo en lo que le toca a este
/// paciente (ver [HomeScreen]).
enum _MoreMenuItem {
  quickTest,
  fullCatalog,
  recommendedCatalog,
  savedSessions,
  settings,
}

/// Pantalla de inicio: saluda al paciente y lo guía directo hacia el/los
/// movimiento(s) de medición que le corresponden según la patología
/// elegida en PatientGateScreen (ver Pathology.exerciseIds) — "Medición
/// del día de hoy", la sección más destacada de la pantalla, ya que es lo
/// que se espera que haga cada vez que abre la app.
///
/// Aparte de eso, con el mismo trato que "Medición del día de hoy" (tarjetas
/// directo en la pantalla, no un solo botón de navegación), están los
/// ejercicios terapéuticos recomendados para su patología (no se graban ni
/// se evalúan — un concepto distinto a la medición, aunque ambos sean
/// "ejercicios" en lenguaje común) y "Mi progreso". Todo lo que no es
/// específico de este paciente (catálogo completo de mediciones, catálogo
/// completo de recomendados, prueba rápida libre, sesiones guardadas) queda
/// detrás del logo/ícono de menú arriba a la izquierda (el mismo logo de
/// Fisiometric, sin un segundo logo grande aparte), para que esta pantalla
/// quede especializada solo en lo suyo — ver RecommendedExerciseCatalogScreen
/// para el catálogo completo.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.patientProfile,
    this.showCoachMarks = false,
  });

  final PatientProfile patientProfile;

  /// `true` justo después de la pantalla de bienvenida (ver
  /// WelcomeScreen) — dispara, una sola vez al construirse esta pantalla,
  /// el recorrido guiado que señala con flechas los botones reales (menú,
  /// medición, recomendados, progreso). `false` en cualquier otra entrada
  /// a Home (paciente que ya había visto todo esto antes).
  final bool showCoachMarks;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late PatientProfile _profile;
  PatientProfile get patientProfile => _profile;

  /// `Exercise.id` de `todaysMeasurements` que el paciente YA registró hoy
  /// — solo para mostrar un indicador en la tarjeta (ver
  /// _TodaysMeasurementCard.isDoneToday), nunca para ocultarla ni bloquear
  /// el tap: una patología como hombro o cadera pide 2 mediciones, y hecha
  /// una de las dos, la otra tiene que seguir disponible para medir (y la
  /// ya hecha, para repetirla si el paciente quiere).
  Set<String> _doneExerciseIdsToday = {};

  // Puntos de referencia para el recorrido guiado (ver [_showCoachMarks]) —
  // uno por cada botón/sección que se señala con flechas.
  final _menuKey = GlobalKey();
  final _measurementKey = GlobalKey();
  final _recommendedKey = GlobalKey();
  final _progressKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _profile = widget.patientProfile;
    WidgetsBinding.instance.addObserver(this);
    // Cubre "recién se confirmó el perfil, esta pantalla se acaba de
    // crear" — el otro caso (la app ya estaba abierta en Home y solo
    // vuelve de segundo plano, sin pasar de nuevo por PatientGateScreen)
    // lo cubre didChangeAppLifecycleState más abajo. Sin esto último, si el
    // paciente nunca vuelve a "Continuar" en un día, el recordatorio de las
    // 8pm de ESE día nunca se reprogramaba — quedaba el de un día anterior.
    DailyReminderService().refresh(patientProfile);
    _loadDoneToday();
    if (widget.showCoachMarks) {
      // Espera al primer frame: recién ahí los GlobalKey ya tienen una
      // posición real en pantalla para que tutorial_coach_mark pueda
      // calcular dónde dibujar el recorte/flecha de cada uno.
      WidgetsBinding.instance.addPostFrameCallback((_) => _showCoachMarks());
    }
  }

  void _showCoachMarks() {
    TutorialCoachMark(
      hideSkip: false,
      textSkip: 'Saltar',
      paddingFocus: 6,
      targets: [
        TargetFocus(
          identify: 'menu',
          keyTarget: _menuKey,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: _CoachMarkText(
                title: 'Menú',
                body:
                    'Acá están tus sesiones guardadas y Configuración: la '
                    'hora de tu recordatorio diario y tus datos personales '
                    '(nombre, cédula, edad, patología).',
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'measurement',
          keyTarget: _measurementKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: _CoachMarkText(
                title: 'Medición del día de hoy',
                body:
                    'Tócalo para ver el video del fisioterapeuta y el '
                    'protocolo antes de grabar, luego mide con la cámara. '
                    'Cuando ya la registraste hoy se pone verde, y igual '
                    'puedes repetirla cuando quieras.',
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'recommended',
          keyTarget: _recommendedKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _CoachMarkText(
                title: 'Ejercicios recomendados',
                body:
                    'Estos no se graban ni se evalúan, son para que los '
                    'repitas por tu cuenta en casa.',
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'progress',
          keyTarget: _progressKey,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _CoachMarkText(
                title: 'Mi progreso',
                body:
                    'Un calendario con tu racha de mediciones (y los días '
                    'que saltaste), y una gráfica que muestra qué tan cerca '
                    'estás de tu meta clínica en cada ejercicio.',
              ),
            ),
          ],
        ),
      ],
      beforeFocus: _scrollTargetIntoView,
      onSkip: () => true,
    ).show(context: context);
  }

  /// Antes de iluminar cada parada del recorrido, la desplaza a una
  /// posición cómoda dentro del `ListView` — sin esto, una tarjeta cerca
  /// del borde de la pantalla (como "Mi progreso", la última) deja muy
  /// poco espacio para el cuadro de texto, que termina superpuesto con la
  /// tarjeta real de abajo. `tutorial_coach_mark` no hace scroll solo, así
  /// que hay que adelantárselo acá antes de que lea la posición del
  /// widget (se llama justo antes de eso, ver paquete).
  Future<void> _scrollTargetIntoView(TargetFocus target) async {
    final ctx = target.keyTarget?.currentContext;
    if (ctx == null || Scrollable.maybeOf(ctx) == null) return;
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.35,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    // Pequeño respiro para que la posición ya esté asentada en el próximo
    // frame, que es cuando el paquete la lee.
    await Future.delayed(const Duration(milliseconds: 80));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DailyReminderService().refresh(patientProfile);
      _loadDoneToday();
    }
  }

  Future<void> _loadDoneToday() async {
    final all = await loadAllSessions(SessionStorageService());
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    final done = all
        .where(
          (s) =>
              s.metadata.patientName == patientProfile.name &&
              isToday(s.metadata.startedAt),
        )
        .map((s) => s.metadata.exerciseId)
        .whereType<String>()
        .toSet();
    if (mounted) setState(() => _doneExerciseIdsToday = done);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsScreen(profile: _profile)),
    );
    // SettingsScreen guarda cada cambio directo a disco a medida que ocurre
    // (no al volver) — se relee acá para que el saludo/patología mostrados
    // arriba queden al día si algo cambió (nombre, patología, etc.).
    final reloaded = await const PatientProfileService().loadLast();
    if (reloaded != null && mounted) setState(() => _profile = reloaded);
  }

  @override
  Widget build(BuildContext context) {
    // Los movimientos sagitales del catálogo están codificados como
    // `derecha` por defecto — se ajustan al lado real que el paciente
    // indicó en PatientGateScreen. Los frontales muestran los dos lados en
    // el mismo cuadro, así que en su caso se restringe qué articulación se
    // mide (no la vista de cámara) — ver Exercise.forPatientSide.
    final todaysMeasurements = exerciseCatalog
        .where((e) => patientProfile.pathology.exerciseIds.contains(e.id))
        .map((e) => e.forPatientSide(patientProfile.affectedSide))
        .toList();
    final recommendedForYou = recommendedExerciseCatalog
        .where((e) => patientProfile.recommendedExerciseIds.contains(e.id))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.tealPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Row(
                children: [
                  PopupMenuButton<_MoreMenuItem>(
                    key: _menuKey,
                    icon: ClipOval(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.white,
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ),
                    onSelected: (item) {
                      switch (item) {
                        case _MoreMenuItem.quickTest:
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => QuickTestViewScreen(
                                patientName: patientProfile.name,
                              ),
                            ),
                          );
                        case _MoreMenuItem.fullCatalog:
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExerciseCatalogScreen(
                                patientName: patientProfile.name,
                                affectedSide: patientProfile.affectedSide,
                              ),
                            ),
                          );
                        case _MoreMenuItem.recommendedCatalog:
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RecommendedExerciseCatalogScreen(
                                patientProfile: patientProfile,
                              ),
                            ),
                          );
                        case _MoreMenuItem.savedSessions:
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SessionsListScreen(),
                            ),
                          );
                        case _MoreMenuItem.settings:
                          _openSettings();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _MoreMenuItem.quickTest,
                        child: ListTile(
                          leading: Icon(Icons.speed_outlined),
                          title: Text('Prueba rápida'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _MoreMenuItem.fullCatalog,
                        child: ListTile(
                          leading: Icon(Icons.fitness_center_outlined),
                          title: Text('Catálogo completo'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _MoreMenuItem.recommendedCatalog,
                        child: ListTile(
                          leading: Icon(Icons.self_improvement_outlined),
                          title: Text('Todos los recomendados'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _MoreMenuItem.savedSessions,
                        child: ListTile(
                          leading: Icon(Icons.folder_open_outlined),
                          title: Text('Sesiones guardadas'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: _MoreMenuItem.settings,
                        child: ListTile(
                          leading: Icon(Icons.settings_outlined),
                          title: Text('Configuración'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Hola, ${patientProfile.name}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${patientProfile.age} años · ${patientProfile.pathology.label}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Column(
                      key: _measurementKey,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Medición del día de hoy',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No son ejercicios para repetir, son los movimientos que '
                          'se registran hoy para seguir tu rango de movimiento.',
                          style: TextStyle(
                            color: AppColors.darkGrey.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final exercise in todaysMeasurements) ...[
                          _TodaysMeasurementCard(
                            exercise: exercise,
                            isDoneToday: _doneExerciseIdsToday.contains(
                              exercise.id,
                            ),
                            onTap: () => Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => ExerciseDemoScreen(
                                      exercise: exercise,
                                      videoAssetPath: exercise
                                          .videoAssetPathFor(
                                            patientProfile.affectedSide,
                                          ),
                                      patientName: patientProfile.name,
                                    ),
                                  ),
                                )
                                // Por si vuelve acá sin pasar por "Volver al
                                // inicio" (que ya recrea HomeScreen de cero) —
                                // por ejemplo, con el botón atrás tras guardar.
                                .then((_) => _loadDoneToday()),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Column(
                      key: _recommendedKey,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Ejercicios recomendados',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ejercicios terapéuticos para tu patología, no se graban '
                          'ni se evalúan, son para repetir por tu cuenta.',
                          style: TextStyle(
                            color: AppColors.darkGrey.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var i = 0;
                              i < recommendedForYou.length;
                              i++
                            ) ...[
                              if (i > 0) const SizedBox(width: 14),
                              Expanded(
                                child: _RecommendedExerciseCard(
                                  exercise: recommendedForYou[i],
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RecommendedExerciseScreen(
                                        exercise: recommendedForYou[i],
                                        patientProfile: patientProfile,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _HomeOptionCard(
                      key: _progressKey,
                      icon: Icons.show_chart_outlined,
                      accentColor: AppColors.tealPrimary,
                      title: 'Mi progreso',
                      subtitle:
                          'Cómo ha ido cambiando tu rango de movimiento sesión '
                          'a sesión, y el detalle de cada medición realizada.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProgressScreen(patientProfile: patientProfile),
                        ),
                      ),
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

/// Tarjeta grande y llamativa para cada movimiento de "Medición del día de
/// hoy" — mucho más prominente que el resto de las opciones del home, ya
/// que es la acción principal que se espera de esta pantalla.
class _TodaysMeasurementCard extends StatelessWidget {
  const _TodaysMeasurementCard({
    required this.exercise,
    required this.onTap,
    this.isDoneToday = false,
  });

  final Exercise exercise;
  final VoidCallback onTap;

  /// `true` si ya se registró este ejercicio hoy — solo cambia el ícono/
  /// etiqueta a modo informativo ("Ya la hiciste hoy" + "Repetir"), nunca
  /// deshabilita el tap: una patología con 2 mediciones (hombro, cadera)
  /// necesita poder seguir midiendo la que falta, y volver a medir la que
  /// ya se hizo si el paciente quiere.
  final bool isDoneToday;

  @override
  Widget build(BuildContext context) {
    final color = isDoneToday ? AppColors.successLight : AppColors.tealPrimary;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDoneToday
                      ? Icons.check_circle_outline
                      : Icons.videocam_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDoneToday
                          ? 'Ya la registraste hoy'
                          : exercise.view.label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isDoneToday ? 'Repetir' : 'Medir',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de "Ejercicios recomendados" — misma familia visual que
/// [_TodaysMeasurementCard] (Material sólido + InkWell + ícono en círculo),
/// pero en naranja (para distinguirla de la medición, en teal) y en formato
/// vertical compacto, pensada para ir de a 2 repartidas en una fila en vez
/// de apiladas: un paciente siempre tiene como máximo 2 recomendados (ver
/// Pathology.recommendedExerciseIds).
class _RecommendedExerciseCard extends StatelessWidget {
  const _RecommendedExerciseCard({required this.exercise, required this.onTap});

  final RecommendedExercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.orangeAccent,
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: AppColors.orangeAccent.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.self_improvement_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                exercise.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Ver',
                  style: TextStyle(
                    color: AppColors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeOptionCard extends StatelessWidget {
  const _HomeOptionCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: accentColor.withValues(alpha: 0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.darkGrey.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Burbuja de texto del recorrido guiado (ver [_HomeScreenState._showCoachMarks])
/// — mismo estilo en las 4 paradas, solo cambia título/cuerpo.
class _CoachMarkText extends StatelessWidget {
  const _CoachMarkText({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
