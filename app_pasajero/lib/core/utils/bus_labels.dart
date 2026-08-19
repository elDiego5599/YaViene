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

/// Etiqueta "ruta - placa" para notificaciones e historial: en vez de
/// "Bus B-042" el usuario ve el NOMBRE de la ruta y la placa, p. ej.
/// "Calle 72 - Uninorte - SQA223".
String routePlateLabel({
  required String busId,
  String? routeName,
  String? routeId,
}) {
  final placa = busPlaca(busId);
  final preferredRoute = routeName?.trim();
  final fallbackRoute = routeId?.trim();
  final route = preferredRoute != null && preferredRoute.isNotEmpty
      ? preferredRoute
      : fallbackRoute;
  if (route == null || route.isEmpty) return placa;
  return placa.isEmpty ? route : '$route - $placa';
}
