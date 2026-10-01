// Lo que el mapa ofrece a un lector de pantalla.
//
// Tocar un bus es lo único que la app pide hacer sobre el dibujo, y con
// VoiceOver encendido eso no se puede: el mapa es una vista nativa sin árbol
// de semántica, así que "toca un bus en el mapa" era un callejón sin salida.
// La pantalla convierte cada entrada de esta lista en una acción
// personalizada del sistema (el rotor de acciones), invisible para quien ve
// la pantalla — el diseño no cambia — y que hace lo mismo que el toque.
//
// El texto se arma aquí, aparte del widget, porque es lo único que hay que
// comprobar: que diga la placa, a cuánto está y en qué estado, y que el
// verbo cambie según el bus ya esté seguido.
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/utils/bus_labels.dart';
import '../../../../core/utils/distancia.dart';
import 'geo.dart';

/// Una acción por bus: a qué bus toca y con qué palabras se anuncia.
typedef AccionDeBus = ({String busId, String etiqueta});

/// Las acciones del mapa para los [buses] de la ruta, en su mismo orden.
///
/// [userLat]/[userLon] son el punto de espera; en `null` (todavía sin pin ni
/// GPS) la etiqueta omite la distancia en vez de inventar una.
List<AccionDeBus> accionesDeBuses({
  required List<BusPosition> buses,
  required double? userLat,
  required double? userLon,
  required Set<String> seleccionados,
}) {
  final acciones = <AccionDeBus>[];
  for (final bus in buses) {
    final distancia = userLat != null && userLon != null
        ? haversineMeters(userLat, userLon, bus.lat, bus.lon)
        : null;
    final donde = distancia == null
        ? ''
        : distancia < 1000
            // Por debajo del kilómetro, los metros redondos: "a 850 m de ti"
            // es la misma frase que la tarjeta de abajo.
            ? ', a ${distancia.round()} m de ti'
            : ', a ${kmLabel(distancia)} de ti';
    final sinSenal = bus.isGhostBus ? ', sin señal' : '';
    final verbo =
        seleccionados.contains(bus.busId) ? 'Dejar de seguir' : 'Seguir';
    acciones.add((
      busId: bus.busId,
      etiqueta: '$verbo el bus ${busPlaca(bus.busId)}$donde$sinSenal',
    ));
  }
  return acciones;
}
