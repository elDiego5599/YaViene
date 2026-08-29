// Validaciones antes de armar un aviso. Antes vivían todas en
// eta_bottom_sheet.dart dentro de _toggleAlert (90 líneas); ahora están
// separadas para que cada regla se vea sola y se pruebe fácil.
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../notifications/presentation/providers/proximity_alerts_provider.dart'
    show alertRadiusMeters;
import '../providers/route_reach_provider.dart' show alertMaxRouteDistanceMeters;

/// Devuelve el mensaje de error si no se puede armar el aviso, o null si
/// todo está bien. No muestra SnackBars ni pide permisos: solo valida.
///
/// [routeDistanceMeters] es lo más que se acerca el recorrido de la ruta al
/// punto del usuario, o **null si no se sabe** (sin ubicación, geometría sin
/// cargar, ruta sin recorrido). Null nunca rechaza: ante la duda se deja
/// armar el aviso.
String? validateAlertActivation({
  required bool hasPosition,
  required BusPosition? bus,
  required bool busAlreadyNear,
  required int activeAlertsCount,
  double? routeDistanceMeters,
}) {
  if (!hasPosition) {
    return 'El aviso necesita saber dónde estás: toca el mapa en tu '
        'ubicación o activa el GPS primero';
  }
  // Va antes que "sin señal" a propósito: si la ruta no pasa por aquí, decir
  // que el aviso se activará cuando el bus vuelva a transmitir sería mentir
  // dos veces —ni va a transmitir cerca, ni esperar sirve de nada—.
  if (routeDistanceMeters != null &&
      routeDistanceMeters > alertMaxRouteDistanceMeters) {
    return 'Esta ruta no pasa cerca de ti: lo más que se acerca son '
        '${_kmLabel(routeDistanceMeters)}, así que el aviso no sonaría nunca. '
        'Mueve tu punto de espera o elige otra ruta';
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

/// Mismo formato que la métrica grande de la hoja ("3.4 km"), sin decimal a
/// partir de 10 km, donde el decimal ya no dice nada.
String _kmLabel(double meters) {
  final km = meters / 1000;
  return km >= 10 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
}
