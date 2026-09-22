import 'dart:io';

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
  /// SessionMetadata. Una articulación sin ninguna muestra válida en toda
  /// la sesión queda fuera del mapa devuelto.
  Map<String, ({double min, double max, double avg})> computeJointStats(
    List<AngleSample> samples,
  ) {
    final result = <String, ({double min, double max, double avg})>{};
    for (final def in jointDefinitions) {
      final values = samples
          .map((s) => s.angles.forJoint(def.kind))
          .whereType<double>()
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
