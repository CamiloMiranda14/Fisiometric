/// Genera un id de sesión legible y ordenable por nombre a partir de la
/// fecha/hora, p.ej. "2026-08-06_14-30-05".
String sessionIdFor(DateTime dateTime) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}'
      '_${two(dateTime.hour)}-${two(dateTime.minute)}-${two(dateTime.second)}';
}
