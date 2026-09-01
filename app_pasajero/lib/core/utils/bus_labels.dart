/// Placa legible de un bus. Los buses reales se registran con el id
/// `BUS-<placa>` (el backend deriva el id desde la placa); los buses demo
/// (B-042, B-055) ya llevan su placa/interno como id.
String busPlaca(String busId) {
  final value = busId.trim();
  final placa = value.startsWith('BUS-') ? value.substring(4) : value;
  return RegExp(r'^[A-Za-z]{3}\d{3}$').hasMatch(placa)
      ? placa.toUpperCase()
      : placa;
}

/// El nombre de la ruta, o su id si no llegó nombre.
String? _ruta(String? routeName, String? routeId) {
  final preferido = routeName?.trim();
  if (preferido != null && preferido.isNotEmpty) return preferido;
  final alterno = routeId?.trim();
  return alterno != null && alterno.isNotEmpty ? alterno : null;
}

/// Etiqueta "ruta - placa" para notificaciones e historial: en vez de
/// "Bus B-042" el usuario ve el NOMBRE de la ruta y la placa, p. ej.
/// "Calle 72 - Uninorte - SQA223".
String routePlateLabel({
  required String busId,
  String? routeName,
  String? routeId,
}) {
  final placa = busPlaca(busId);
  final route = _ruta(routeName, routeId);
  if (route == null) return placa;
  return placa.isEmpty ? route : '$route - $placa';
}

/// La misma etiqueta, dicha en voz alta.
///
/// En pantalla el guion separa la ruta de la placa y se entiende de un
/// vistazo; leído, «Calle 72 guion SQA223» no dice qué es cada cosa. Esto
/// nombra las dos partes.
String routePlateSpoken({
  required String busId,
  String? routeName,
  String? routeId,
}) {
  final placa = busPlaca(busId);
  final route = _ruta(routeName, routeId);
  if (route == null) return placa.isEmpty ? '' : 'Bus $placa';
  return placa.isEmpty ? route : '$route, bus $placa';
}
