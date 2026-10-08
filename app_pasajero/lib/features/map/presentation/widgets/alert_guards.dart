// Validaciones antes de armar un aviso. Antes vivían todas en
// eta_bottom_sheet.dart dentro de _toggleAlert (90 líneas); ahora están
// separadas para que cada regla se vea sola y se pruebe fácil.
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/utils/distancia.dart';
import '../../../notifications/presentation/providers/distancia_aviso_provider.dart'
    show distanciaAvisoMaxima;

/// Devuelve el mensaje de error si no se puede armar el aviso, o null si
/// todo está bien. No muestra SnackBars ni pide permisos: solo valida.
///
/// [routeDistanceMeters] es lo más que se acerca el recorrido de la ruta al
/// punto del usuario, o **null si no se sabe** (sin ubicación, geometría sin
/// cargar, ruta sin recorrido). Null nunca rechaza: ante la duda se deja
/// armar el aviso. Lo mismo [busDistanceMeters]: null es no saber dónde va
/// el bus. Las dos se miden por la ruta.
///
/// [radioCercaM] y [radioRutaM] son la distancia a la que sonaría el aviso.
/// Con la distancia ya elegida, las dos son esa. Antes de elegirla se valida
/// solo lo que ninguna opción de la rueda arreglaría: el bus ya encima con
/// la mínima y la ruta lejos con la máxima.
String? validateAlertActivation({
  required bool hasPosition,
  required BusPosition? bus,
  required double? busDistanceMeters,
  required int activeAlertsCount,
  double? routeDistanceMeters,
  required int radioCercaM,
  required int radioRutaM,
}) {
  if (!hasPosition) {
    return 'El aviso necesita saber dónde estás: toca el mapa en tu '
        'ubicación o activa el GPS primero';
  }
  // Va antes que "sin señal" a propósito: si la ruta no pasa por aquí, decir
  // que el aviso se activará cuando el bus vuelva a transmitir sería mentir
  // dos veces —ni va a transmitir cerca, ni esperar sirve de nada—.
  if (routeDistanceMeters != null && routeDistanceMeters > radioRutaM) {
    // Con la distancia por debajo de 3 km, subirla es la salida más corta.
    return radioRutaM < distanciaAvisoMaxima
        ? 'Esta ruta no pasa cerca de ti: lo más que se acerca son '
            '${kmLabel(routeDistanceMeters)} y tu aviso suena a '
            '${distanciaAviso(radioRutaM)}, así que no sonaría nunca. '
            'Elige una distancia mayor, mueve tu punto de espera o elige '
            'otra ruta'
        : 'Esta ruta no pasa cerca de ti: lo más que se acerca son '
            '${kmLabel(routeDistanceMeters)} y el aviso suena a '
            '${distanciaAvisoMaxima ~/ 1000} km como mucho, así que no '
            'sonaría nunca. Mueve tu punto de espera o elige otra ruta';
  }
  if (bus != null && bus.isGhostBus) {
    return 'El bus ${bus.busId} está sin señal; el aviso se activa '
        'cuando vuelva a transmitir';
  }
  if (bus != null &&
      busDistanceMeters != null &&
      busDistanceMeters <= radioCercaM) {
    return 'El bus ${bus.busId} ya está a menos de '
        '${distanciaAviso(radioCercaM)}; no se puede activar el aviso';
  }
  if (activeAlertsCount >= 2) return avisosAlTope;
  return null;
}

/// Lo que se dice al pasar del tope de 2 avisos activos: al armar uno y al
/// deshacer un borrado cuando ya se armaron otros dos.
const avisosAlTope = 'Ya tienes 2 avisos activos: desactiva uno o espera a '
    'que termine para activar otro. Recuerda no cerrar la aplicación';

/// Lo que se dice cuando el bus ya va más cerca de lo que la ruta se acerca
/// al punto: lo que el bus todavía no ha pasado no alcanza la ruta y ninguna
/// distancia de la rueda sonaría. [accion], lo que no se puede hacer.
String sinDistanciaQueSirva(String busId, String accion) =>
    'El bus $busId ya va por lo más cerca que te pasa su ruta; no se puede '
    '$accion';
