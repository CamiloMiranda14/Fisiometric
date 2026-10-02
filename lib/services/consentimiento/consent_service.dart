import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Un consentimiento informado ya aceptado — queda guardado para no volver
/// a pedirlo si la misma cédula vuelve a usar este teléfono otro día (ver
/// [ConsentService.hasConsented]).
class ConsentRecord {
  const ConsentRecord({
    required this.cedula,
    required this.signedName,
    required this.cedulaIssuedCity,
    required this.acceptedAt,
  });

  final String cedula;

  /// Nombre que la persona escribió como firma al aceptar — puede diferir
  /// ligeramente del nombre del perfil (p.ej. con segundo nombre), así que
  /// se guarda aparte en vez de asumir que es el mismo.
  final String signedName;

  /// Ciudad de expedición de la cédula — dato que pide el documento de
  /// consentimiento pero que el resto de la app no necesita, por eso no
  /// vive en `PatientProfile`.
  final String cedulaIssuedCity;

  final DateTime acceptedAt;

  Map<String, dynamic> toJson() => {
    'cedula': cedula,
    'signedName': signedName,
    'cedulaIssuedCity': cedulaIssuedCity,
    'acceptedAt': acceptedAt.toIso8601String(),
  };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
    cedula: json['cedula'] as String,
    signedName: json['signedName'] as String,
    cedulaIssuedCity: json['cedulaIssuedCity'] as String,
    acceptedAt: DateTime.parse(json['acceptedAt'] as String),
  );
}

/// Guarda qué cédulas ya aceptaron el consentimiento informado en ESTE
/// teléfono — el mismo dispositivo pasa de paciente en paciente durante el
/// día (ver PatientGateScreen), así que el consentimiento se pide una sola
/// vez POR CÉDULA, no una vez por dispositivo ni cada vez que se abre la
/// app: una cédula nueva siempre lo ve la primera vez que usa el teléfono,
/// una que vuelve (cualquier día después) ya no.
///
/// El mismo criterio ("¿es la primera vez que esta cédula usa el
/// teléfono?") también decide si se muestra la pantalla de bienvenida y el
/// recorrido guiado (ver WelcomeScreen/HomeScreen.showCoachMarks) — es la
/// misma pregunta, así que no hace falta un segundo archivo para eso.
class ConsentService {
  const ConsentService();

  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/consent_records.json');
  }

  Future<Map<String, ConsentRecord>> _readAll() async {
    final file = await _file();
    if (!await file.exists()) return {};
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return {};
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return data.map(
      (cedula, json) => MapEntry(cedula, ConsentRecord.fromJson(json as Map<String, dynamic>)),
    );
  }

  Future<bool> hasConsented(String cedula) async {
    final all = await _readAll();
    return all.containsKey(cedula);
  }

  Future<void> recordConsent({
    required String cedula,
    required String signedName,
    required String cedulaIssuedCity,
  }) async {
    final all = await _readAll();
    all[cedula] = ConsentRecord(
      cedula: cedula,
      signedName: signedName,
      cedulaIssuedCity: cedulaIssuedCity,
      acceptedAt: DateTime.now(),
    );
    final file = await _file();
    await file.writeAsString(jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))));
  }
}
