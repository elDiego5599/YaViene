// Validaciones antes de armar un aviso. Antes vivían todas en
// eta_bottom_sheet.dart dentro de _toggleAlert (90 líneas); ahora están
// separadas para que cada regla se vea sola y se pruebe fácil.
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../notifications/presentation/providers/proximity_alerts_provider.dart'
    show alertRadiusMeters;

/// Devuelve el mensaje de error si no se puede armar el aviso, o null si
/// todo está bien. No muestra SnackBars ni pide permisos: solo valida.
String? validateAlertActivation({
  required bool hasPosition,
  required BusPosition? bus,
  required bool busAlreadyNear,
  required int activeAlertsCount,
}) {
  if (!hasPosition) {
    return 'El aviso necesita saber dónde estás: toca el mapa en tu '
        'ubicación o activa el GPS primero';
  }
  if (bus != null && bus.isGhostBus) {
    return 'El bus ${bus.busId} está sin señal; el aviso se activa cuando vuelva a transmitir';
  }
  if (busAlreadyNear) {
    return 'El bus ${bus!.busId} ya está a menos de $alertRadiusMeters m; '
        'no se puede activar el aviso';
  }
  if (activeAlertsCount >= 2) {
    return 'Ya tienes 2 avisos activos: desactiva uno o espera a que '
        'termine para activar otro. Recuerda no cerrar la aplicación';
  }
  return null;
}
