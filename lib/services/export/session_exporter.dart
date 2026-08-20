import 'dart:io';

import 'package:excel/excel.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/pose/angle_calculator.dart';
import '../../core/pose/body_view.dart';
import '../../models/angle_sample.dart';

/// Escribe los datos de ángulos de una sesión en CSV y en .xlsx.
///
/// El CSV se arma a mano (sin el paquete `csv`): los datos son 100%
/// numéricos, sin comas ni saltos de línea que escapar, así que una
/// librería no aporta nada aquí y es una dependencia menos.
///
/// Las columnas dependen de la vista de la sesión: en `izquierda`/`derecha`
/// solo se incluyen las articulaciones de ese lado (y no hay columnas de
/// simetría, que solo tiene sentido en `frontal`) — ver `BodyView`.
class SessionExporter {
  const SessionExporter();

  List<JointDefinition> _activeDefs(BodyView view) =>
      jointDefinitions.where((d) => isJointActiveForView(d.kind, view)).toList();

  List<String> _headers(BodyView view, List<JointDefinition> activeDefs) => [
    'tiempo_ms',
    'frame',
    for (final def in activeDefs) def.csvColumn,
    for (final def in activeDefs) 'vel_${def.csvColumn}',
    if (view == BodyView.frontal)
      for (final pair in symmetricJointPairs) 'sim_${pair.csvColumn}',
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
        if (view == BodyView.frontal)
          for (final pair in symmetricJointPairs)
            _formatCell(sample.symmetry.forPair(pair.pair)),
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

  Future<File> writeXlsx(
    String path,
    List<AngleSample> samples,
    BodyView view,
  ) async {
    final activeDefs = _activeDefs(view);
    final workbook = Excel.createExcel();
    const sheetName = 'Ángulos';
    final sheet = workbook[sheetName];
    // Excel.createExcel() siempre trae una hoja por defecto vacía ("Sheet1");
    // se elimina para que la exportada quede como única hoja.
    for (final existing in List.of(workbook.sheets.keys)) {
      if (existing != sheetName) workbook.delete(existing);
    }

    sheet.appendRow(_headers(view, activeDefs).map(TextCellValue.new).toList());
    for (final sample in samples) {
      sheet.appendRow([
        IntCellValue(sample.timestampMs),
        IntCellValue(sample.frameIndex),
        for (final def in activeDefs)
          _cellValue(sample.angles.forJoint(def.kind)),
        for (final def in activeDefs)
          _cellValue(sample.velocity.forJoint(def.kind)),
        if (view == BodyView.frontal)
          for (final pair in symmetricJointPairs)
            _cellValue(sample.symmetry.forPair(pair.pair)),
      ]);
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw const ExportException('No se pudo generar el archivo .xlsx.');
    }

    try {
      final file = File(path);
      await file.create(recursive: true);
      return await file.writeAsBytes(bytes);
    } on IOException catch (e) {
      throw ExportException('No se pudo escribir el .xlsx: $e');
    }
  }

  DoubleCellValue? _cellValue(double? value) =>
      value == null ? null : DoubleCellValue(value);

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

  /// Promedio de simetría bilateral (SI %) por par de articulaciones, para
  /// `session.json`. Solo tiene datos en `BodyView.frontal` — en
  /// izquierda/derecha retorna un mapa vacío, ya que no hay con qué
  /// comparar (ver `computeBilateralSymmetry`).
  Map<String, double> computeSymmetryStats(
    List<AngleSample> samples,
    BodyView view,
  ) {
    if (view != BodyView.frontal) return {};

    final result = <String, double>{};
    for (final pair in symmetricJointPairs) {
      final values = samples
          .map((s) => s.symmetry.forPair(pair.pair))
          .whereType<double>()
          .toList();
      if (values.isEmpty) continue;
      result[pair.csvColumn] = values.reduce((a, b) => a + b) / values.length;
    }
    return result;
  }
}
