/// Genera un id de sesión legible y ordenable por nombre a partir de la
/// fecha/hora, p.ej. "2026-08-06_14-30-05".
String sessionIdFor(DateTime dateTime) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}'
      '_${two(dateTime.hour)}-${two(dateTime.minute)}-${two(dateTime.second)}';
}

const _monthNames = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Fecha en palabras, sin hora — p.ej. "22 de septiembre de 2026". Único
/// formato que debería usarse en cualquier lugar donde una sesión se
/// identifique por fecha frente al paciente (título de SessionDetailScreen,
/// listas de sesiones, gráficas de progreso) — a diferencia de
/// `sessionIdFor` (para nombrar archivos) o un DD/MM/AAAA numérico, que se
/// lee más lento y no distingue tan bien "es una fecha" de otro número en
/// pantalla.
String formatDateWords(DateTime d) => '${d.day} de ${_monthNames[d.month - 1]} de ${d.year}';
