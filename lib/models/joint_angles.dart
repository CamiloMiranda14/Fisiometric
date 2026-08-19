import '../core/pose/angle_calculator.dart';
import '../core/pose/body_view.dart';
import 'pose_frame.dart';

/// Los 8 ángulos articulares medidos en un instante, en grados.
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
    rodillaIzq: null,
    rodillaDer: null,
  );

  final double? hombroIzq;
  final double? hombroDer;
  final double? codoIzq;
  final double? codoDer;
  final double? munecaIzq;
  final double? munecaDer;
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
      case JointKind.rodillaIzq:
        return rodillaIzq;
      case JointKind.rodillaDer:
        return rodillaDer;
    }
  }

  /// Mismo orden que las columnas del CSV/Excel — ver SessionExporter (Fase 5).
  List<double?> get asOrderedList => [
    hombroIzq,
    hombroDer,
    codoIzq,
    codoDer,
    munecaIzq,
    munecaDer,
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
      rodillaIzq: keepIfActive(JointKind.rodillaIzq, rodillaIzq),
      rodillaDer: keepIfActive(JointKind.rodillaDer, rodillaDer),
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
      return angle.isNaN ? null : angle;
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
      rodillaIzq: values[JointKind.rodillaIzq],
      rodillaDer: values[JointKind.rodillaDer],
    );
  }
}
