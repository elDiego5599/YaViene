/// Placa legible de un bus. Los buses reales se registran con el id
/// `BUS-<placa>` (el backend deriva el id desde la placa); los buses demo
/// (B-042, B-055) ya llevan su placa/interno como id.
String busPlaca(String busId) =>
    busId.startsWith('BUS-') ? busId.substring(4) : busId;

/// Etiqueta "ruta · placa" para notificaciones e historial: en vez de
/// "Bus B-042" el usuario ve la ruta y la placa, p. ej. "Ruta 1 · B-042".
String routePlateLabel({
  required String busId,
  String? routeName,
  String? routeId,
}) {
  final placa = busPlaca(busId);
  final route = routeName ?? routeId ?? '';
  return route.isEmpty ? placa : '$route · $placa';
}