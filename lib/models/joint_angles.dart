import '../core/pose/angle_calculator.dart';
import '../core/pose/body_region.dart';
import '../core/pose/body_view.dart';
import 'pose_frame.dart';

/// Los 10 ángulos articulares medidos en un instante, en grados.
///
/// `null` significa que esa articulación no tenía suficiente confianza
/// (landmark no visible u oculto) en ese frame — no "ángulo cero".
class JointAngles {
  const JointAngles({
    required this.hombroIzq,
    required this.hombroDer,
    required this.codoIzq,
    required this.codoDer,
    required this.munecaIzq,
    required this.munecaDer,
    required this.caderaIzq,
    required this.caderaDer,
    required this.rodillaIzq,
    required this.rodillaDer,
  });

  static const empty = JointAngles(
    hombroIzq: null,
    hombroDer: null,
    codoIzq: null,
    codoDer: null,
    munecaIzq: null,
    munecaDer: null,
    caderaIzq: null,
    caderaDer: null,
    rodillaIzq: null,
    rodillaDer: null,
  );

  final double? hombroIzq;
  final double? hombroDer;
  final double? codoIzq;
  final double? codoDer;
  final double? munecaIzq;
  final double? munecaDer;
  final double? caderaIzq;
  final double? caderaDer;
  final double? rodillaIzq;
  final double? rodillaDer;

  double? forJoint(JointKind kind) {
    switch (kind) {
      case JointKind.hombroIzq:
        return hombroIzq;
      case JointKind.hombroDer:
        return hombroDer;
      case JointKind.codoIzq:
        return codoIzq;
      case JointKind.codoDer:
        return codoDer;
      case JointKind.munecaIzq:
        return munecaIzq;
      case JointKind.munecaDer:
        return munecaDer;
      case JointKind.caderaIzq:
        return caderaIzq;
      case JointKind.caderaDer:
        return caderaDer;
      case JointKind.rodillaIzq:
        return rodillaIzq;
      case JointKind.rodillaDer:
        return rodillaDer;
    }
  }

  /// Mismo orden que las columnas del CSV — ver SessionExporter (Fase 5).
  List<double?> get asOrderedList => [
    hombroIzq,
    hombroDer,
    codoIzq,
    codoDer,
    munecaIzq,
    munecaDer,
    caderaIzq,
    caderaDer,
    rodillaIzq,
    rodillaDer,
  ];

  /// Anula (pone en `null`) los ángulos del lado no activo en [view]. En
  /// `BodyView.frontal` retorna `this` sin cambios.
  JointAngles filterForView(BodyView view) {
    if (view == BodyView.frontal) return this;

    double? keepIfActive(JointKind kind, double? value) =>
        isJointActiveForView(kind, view) ? value : null;

    return JointAngles(
      hombroIzq: keepIfActive(JointKind.hombroIzq, hombroIzq),
      hombroDer: keepIfActive(JointKind.hombroDer, hombroDer),
      codoIzq: keepIfActive(JointKind.codoIzq, codoIzq),
      codoDer: keepIfActive(JointKind.codoDer, codoDer),
      munecaIzq: keepIfActive(JointKind.munecaIzq, munecaIzq),
      munecaDer: keepIfActive(JointKind.munecaDer, munecaDer),
      caderaIzq: keepIfActive(JointKind.caderaIzq, caderaIzq),
      caderaDer: keepIfActive(JointKind.caderaDer, caderaDer),
      rodillaIzq: keepIfActive(JointKind.rodillaIzq, rodillaIzq),
      rodillaDer: keepIfActive(JointKind.rodillaDer, rodillaDer),
    );
  }

  /// Anula (pone en `null`) los ángulos que no pertenecen a [region] — p.ej.
  /// rodilla si `region == BodyRegion.upperBody`. En `BodyRegion.fullBody`
  /// retorna `this` sin cambios.
  JointAngles filterForRegion(BodyRegion region) {
    if (region == BodyRegion.fullBody) return this;

    double? keepIfActive(JointKind kind, double? value) =>
        isJointActiveForRegion(kind, region) ? value : null;

    return JointAngles(
      hombroIzq: keepIfActive(JointKind.hombroIzq, hombroIzq),
      hombroDer: keepIfActive(JointKind.hombroDer, hombroDer),
      codoIzq: keepIfActive(JointKind.codoIzq, codoIzq),
      codoDer: keepIfActive(JointKind.codoDer, codoDer),
      munecaIzq: keepIfActive(JointKind.munecaIzq, munecaIzq),
      munecaDer: keepIfActive(JointKind.munecaDer, munecaDer),
      caderaIzq: keepIfActive(JointKind.caderaIzq, caderaIzq),
      caderaDer: keepIfActive(JointKind.caderaDer, caderaDer),
      rodillaIzq: keepIfActive(JointKind.rodillaIzq, rodillaIzq),
      rodillaDer: keepIfActive(JointKind.rodillaDer, rodillaDer),
    );
  }

  /// Anula (pone en `null`) los ángulos que no están en [allowed] — p.ej.
  /// codo/muñeca en un ejercicio que solo trackea hombro (ver
  /// `Exercise.trackedJoints`). `null` (sin ejercicio específico, como en
  /// "Prueba rápida") retorna `this` sin cambios.
  JointAngles filterForJoints(Set<JointKind>? allowed) {
    if (allowed == null) return this;

    double? keepIfAllowed(JointKind kind, double? value) =>
        allowed.contains(kind) ? value : null;

    return JointAngles(
      hombroIzq: keepIfAllowed(JointKind.hombroIzq, hombroIzq),
      hombroDer: keepIfAllowed(JointKind.hombroDer, hombroDer),
      codoIzq: keepIfAllowed(JointKind.codoIzq, codoIzq),
      codoDer: keepIfAllowed(JointKind.codoDer, codoDer),
      munecaIzq: keepIfAllowed(JointKind.munecaIzq, munecaIzq),
      munecaDer: keepIfAllowed(JointKind.munecaDer, munecaDer),
      caderaIzq: keepIfAllowed(JointKind.caderaIzq, caderaIzq),
      caderaDer: keepIfAllowed(JointKind.caderaDer, caderaDer),
      rodillaIzq: keepIfAllowed(JointKind.rodillaIzq, rodillaIzq),
      rodillaDer: keepIfAllowed(JointKind.rodillaDer, rodillaDer),
    );
  }

  factory JointAngles.fromPoseFrame(PoseFrame frame) {
    if (!frame.hasPose) return empty;

    double? angleFor(JointDefinition def) {
      final a = frame[def.a];
      final vertex = frame[def.vertex];
      final c = frame[def.c];
      if (a == null || vertex == null || c == null) return null;
      if (a.visibility < kMinLandmarkVisibility ||
          vertex.visibility < kMinLandmarkVisibility ||
          c.visibility < kMinLandmarkVisibility) {
        return null;
      }
      final angle = angleAtVertex(a, vertex, c);
      if (angle.isNaN) return null;

      // `angleAtVertex` da el ángulo interior crudo (180° = articulación
      // extendida, como un goniómetro físico — ver ese comentario). Para
      // hombro eso YA se lee como "grados de flexión desde 0" porque usa
      // la cadera como referencia externa fija (brazo al costado ≈ 0°). Para
      // codo/muñeca/cadera/rodilla, que miden el ángulo del propio eje del
      // miembro, es al revés (180° = extendido, BAJA al flexionar) — se
      // invierte aquí (180 - ángulo) para que en vivo, en el CSV exportado
      // y en cualquier otro consumidor de `JointAngles` el número siempre
      // suba con la flexión y la extensión completa se lea como 0°, igual
      // que reporta un goniómetro clínico. Este es el único lugar donde se
      // aplica esta conversión — todo lo que lea `JointAngles` de acá en
      // adelante (HUD, esqueleto, velocidad angular, CSV/jointStats,
      // gráficas de progreso) ya recibe el valor convertido.
      final isHombro = def.kind == JointKind.hombroIzq || def.kind == JointKind.hombroDer;
      return isHombro ? angle : (180 - angle);
    }

    final values = <JointKind, double?>{
      for (final def in jointDefinitions) def.kind: angleFor(def),
    };

    return JointAngles(
      hombroIzq: values[JointKind.hombroIzq],
      hombroDer: values[JointKind.hombroDer],
      codoIzq: values[JointKind.codoIzq],
      codoDer: values[JointKind.codoDer],
      munecaIzq: values[JointKind.munecaIzq],
      munecaDer: values[JointKind.munecaDer],
      caderaIzq: values[JointKind.caderaIzq],
      caderaDer: values[JointKind.caderaDer],
      rodillaIzq: values[JointKind.rodillaIzq],
      rodillaDer: values[JointKind.rodillaDer],
    );
  }
}
