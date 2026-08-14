import 'dart:io';

import 'package:excel/excel.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/pose/angle_calculator.dart';
import '../../models/angle_sample.dart';

/// Escribe los datos de ángulos de una sesión en CSV y en .xlsx.
///
/// El CSV se arma a mano (sin el paquete `csv`): los datos son 100%
/// numéricos, sin comas ni saltos de línea que escapar, así que una
/// librería no aporta nada aquí y es una dependencia menos.
class SessionExporter {
  const SessionExporter();

  static const List<String> _headers = [
    'tiempo_ms',
    'frame',
    ...['hombro_izq', 'hombro_der', 'codo_izq', 'codo_der', 'muneca_izq', 'muneca_der', 'rodilla_izq', 'rodilla_der'],
  ];

  Future<File> writeCsv(String path, List<AngleSample> samples) async {
    final buffer = StringBuffer()..writeln(_headers.join(','));
    for (final sample in samples) {
      final cells = <String>[
        '${sample.timestampMs}',
        '${sample.frameIndex}',
        for (final value in sample.angles.asOrderedList)
          value == null ? '' : value.toStringAsFixed(1),
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

  Future<File> writeXlsx(String path, List<AngleSample> samples) async {
    final workbook = Excel.createExcel();
    const sheetName = 'Ángulos';
    final sheet = workbook[sheetName];
    // Excel.createExcel() siempre trae una hoja por defecto vacía ("Sheet1");
    // se elimina para que la exportada quede como única hoja.
    for (final existing in List.of(workbook.sheets.keys)) {
      if (existing != sheetName) workbook.delete(existing);
    }

    sheet.appendRow(_headers.map(TextCellValue.new).toList());
    for (final sample in samples) {
      sheet.appendRow([
        IntCellValue(sample.timestampMs),
        IntCellValue(sample.frameIndex),
        for (final value in sample.angles.asOrderedList)
          value == null ? null : DoubleCellValue(value),
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
}
