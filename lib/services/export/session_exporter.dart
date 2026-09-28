import 'dart:io';
import 'dart:math' as math;

import '../../core/errors/app_exceptions.dart';
import '../../core/pose/angle_calculator.dart';
import '../../core/pose/body_view.dart';
import '../../models/angle_sample.dart';

/// Escribe los datos de ángulos de una sesión en CSV — se abre igual de
/// bien en Excel/Sheets/Numbers que un .xlsx, sin necesitar una librería
/// aparte para generarlo (antes también se exportaba un .xlsx con el
/// paquete `excel`, pero ningún archivo de la app lo leía de vuelta —solo
/// se compartía— así que se quitó esa dependencia).
///
/// El CSV se arma a mano (sin el paquete `csv`): los datos son 100%
/// numéricos, sin comas ni saltos de línea que escapar, así que una
/// librería no aporta nada aquí y es una dependencia menos.
///
/// Las columnas dependen de la vista de la sesión: en `izquierda`/`derecha`
/// solo se incluyen las articulaciones de ese lado — ver `BodyView`.
class SessionExporter {
  const SessionExporter();

  List<JointDefinition> _activeDefs(BodyView view) =>
      jointDefinitions.where((d) => isJointActiveForView(d.kind, view)).toList();

  List<String> _headers(BodyView view, List<JointDefinition> activeDefs) => [
    'tiempo_ms',
    'frame',
    for (final def in activeDefs) def.csvColumn,
    for (final def in activeDefs) 'vel_${def.csvColumn}',
  ];

  Future<File> writeCsv(
    String path,
    List<AngleSample> samples,
    BodyView view,
  ) async {
    final activeDefs = _activeDefs(view);
    final buffer = StringBuffer()..writeln(_headers(view, activeDefs).join(','));
    for (final sample in samples) {
      final cells = <String>[
        '${sample.timestampMs}',
        '${sample.frameIndex}',
        for (final def in activeDefs) _formatCell(sample.angles.forJoint(def.kind)),
        for (final def in activeDefs)
          _formatCell(sample.velocity.forJoint(def.kind)),
      ];
      buffer.writeln(cells.join(','));
    }

    try {
      final file = File(path);
      await file.create(recursive: true);
      return await file.writeAsString(buffer.toString());
    } on IOException catch (e) {
      throw ExportException('No se pudo escribir el CSV: $e');
    }
  }

  String _formatCell(double? value) =>
      value == null ? '' : value.toStringAsFixed(1);

  /// Mín/máx/promedio por articulación, para `session.json` — ver
  /// SessionMetadata. Una articulación sin ninguna muestra válida (o donde
  /// TODAS sus lecturas superaron el límite biomecánico plausible, ver
  /// `plausibilityCeilingFor`) queda fuera del mapa devuelto. Las lecturas
  /// que sí superan ese límite se descartan del cálculo — no cuentan como
  /// "rango logrado" real, casi siempre son ruido del detector.
  Map<String, ({double min, double max, double avg})> computeJointStats(
    List<AngleSample> samples, {
    String? exerciseId,
  }) {
    final result = <String, ({double min, double max, double avg})>{};
    for (final def in jointDefinitions) {
      final ceiling = plausibilityCeilingFor(def.kind, exerciseId: exerciseId);
      final values = samples
          .map((s) => s.angles.forJoint(def.kind))
          .whereType<double>()
          .where((v) => v <= ceiling)
          .toList();
      if (values.isEmpty) continue;
      final sum = values.reduce((a, b) => a + b);
      result[def.csvColumn] = (
        min: values.reduce((a, b) => a < b ? a : b),
        max: values.reduce((a, b) => a > b ? a : b),
        avg: sum / values.length,
      );
    }
    return result;
  }

  /// Columnas (`JointDefinition.csvColumn`) donde una parte importante de
  /// las lecturas crudas de la sesión superó el límite biomecánico
  /// plausible — señal de que el detector probablemente perdió el punto
  /// real de esa articulación durante buena parte de la sesión, no de que
  /// el paciente de verdad alcanzó ese rango (ver `computeJointStats`, que
  /// ya descarta esas lecturas puntuales del min/prom/máx). Se usa para
  /// avisarle al paciente que quizás el ejercicio no se ejecutó bien
  /// encuadrado y convendría repetir la medición — ver
  /// FriendlySessionSummary/SessionDetailScreen.
  Set<String> computeUnreliableJoints(
    List<AngleSample> samples, {
    String? exerciseId,
  }) {
    const minSamples = 5;
    const unreliableFraction = 0.3;
    final result = <String>{};
    for (final def in jointDefinitions) {
      final ceiling = plausibilityCeilingFor(def.kind, exerciseId: exerciseId);
      final values = samples.map((s) => s.angles.forJoint(def.kind)).whereType<double>().toList();
      if (values.length < minSamples) continue;
      final implausibleCount = values.where((v) => v > ceiling).length;
      if (implausibleCount / values.length >= unreliableFraction) {
        result.add(def.csvColumn);
      }
    }
    return result;
  }

  /// Columnas donde el paciente parece haber "estabilizado" el movimiento
  /// en algún momento de la sesión — sostuvo una posición cercana a su
  /// máximo el tiempo suficiente como para que no sea solo un pico
  /// instantáneo de ruido. No hay un número fijo de "rango máximo normal"
  /// que sirva para todos: varía por persona (masa muscular, patología,
  /// etc.), así que en vez de comparar contra un valor absoluto, se busca
  /// la racha sostenida más larga cerca del propio máximo de la sesión.
  ///
  /// A propósito NO se asume que ese sostenido pasa al final de la
  /// grabación: mucha gente se graba sola, así que el último tramo del
  /// video suele ser la persona caminando hacia el teléfono para detener
  /// la grabación, no sosteniendo el estiramiento — analizar solo la cola
  /// del video daría falsos negativos (o positivos, si el movimiento al
  /// caminar pasa por casualidad cerca del mismo ángulo). Se busca la
  /// racha más larga en CUALQUIER punto de la sesión en su lugar (ver
  /// MeasurementProtocolScreen, que le pide al paciente sostener el
  /// estiramiento unos segundos antes de soltar — sin eso, esta señal no
  /// tiene con qué detectarse).
  Set<String> computePlateauedJoints(List<AngleSample> samples) {
    const minSamples = 10;
    const closeToMaxThreshold = 4.0; // ° — qué tan cerca del máximo de la sesión
    const minHoldMs = 600; // sostenido al menos ~0.6s cerca del máximo
    const maxGapMs = 350; // tolera cortes cortos de ruido dentro del sostenido

    final result = <String>{};
    for (final def in jointDefinitions) {
      final series = samples
          .map((s) => (s.timestampMs, s.angles.forJoint(def.kind)))
          .where((e) => e.$2 != null)
          .map((e) => (ms: e.$1, value: e.$2!))
          .toList();
      if (series.length < minSamples) continue;

      final overallMax = series.map((e) => e.value).reduce((a, b) => a > b ? a : b);

      int? runStartMs;
      int? lastCloseMs;
      var bestDurationMs = 0;
      for (final sample in series) {
        final isClose = (overallMax - sample.value) <= closeToMaxThreshold;
        if (!isClose) continue;
        if (runStartMs == null) {
          runStartMs = sample.ms;
        } else if (lastCloseMs != null && sample.ms - lastCloseMs > maxGapMs) {
          bestDurationMs = math.max(bestDurationMs, lastCloseMs - runStartMs);
          runStartMs = sample.ms;
        }
        lastCloseMs = sample.ms;
      }
      if (runStartMs != null && lastCloseMs != null) {
        bestDurationMs = math.max(bestDurationMs, lastCloseMs - runStartMs);
      }

      if (bestDurationMs >= minHoldMs) {
        result.add(def.csvColumn);
      }
    }
    return result;
  }

  /// Promedio de velocidad angular por articulación (°/s), para
  /// `session.json`. Se promedia el **valor absoluto** de cada muestra, no
  /// el valor con signo: un ejercicio de ida y vuelta (ej. flexo-extensión)
  /// tiene velocidad positiva y negativa que se cancelarían cerca de 0 si
  /// se promediara con signo, dando un número inútil. El valor absoluto
  /// refleja la "rapidez" típica del movimiento. Articulación sin ninguna
  /// muestra válida queda fuera del mapa.
  Map<String, double> computeVelocityStats(List<AngleSample> samples) {
    final result = <String, double>{};
    for (final def in jointDefinitions) {
      final values = samples
          .map((s) => s.velocity.forJoint(def.kind))
          .whereType<double>()
          .map((v) => v.abs())
          .toList();
      if (values.isEmpty) continue;
      result[def.csvColumn] = values.reduce((a, b) => a + b) / values.length;
    }
    return result;
  }
}
