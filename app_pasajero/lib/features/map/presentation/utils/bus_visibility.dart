// Qué buses se pintan en el mapa.
//
// El mapa dibujaba todos los buses de la ruta. En una ruta de 30 km eso son
// vehículos a 15 km del usuario compitiendo por el mismo espacio que el que
// está a la vuelta de la esquina: el mapa se satura, el usuario no distingue
// cuál es "el suyo", y la app gasta batería animando iconos que no le
// importan a nadie. Se recorta a un radio alrededor del punto de espera.
//
// Esto es solo la vista. Los avisos armados siguen midiendo contra TODOS los
// buses de la ruta (proximity_alerts_provider lee la fuente sin filtrar): un
// bus que hoy está a 7 km es exactamente el que mañana dispara el aviso al
// entrar al kilómetro. Filtrar lo que se dibuja no puede apagar lo que mide.
import 'package:ya_viene_core/ya_viene_core.dart';

import 'geo.dart';

/// Radio del punto de espera dentro del cual se pintan los buses.
const int visibleRadiusMeters = 5000;

/// Radio de salida. Un bus entra a 5 km y no se va hasta pasar de 5,5 km.
///
/// Sin este margen, un bus rondando justo el límite —y con el pin del GPS
/// moviéndose unos metros— parpadea: aparece, desaparece, aparece. Medio
/// kilómetro de banda muerta cuesta nada y quita el parpadeo entero.
const int visibleRadiusExitMeters = 5500;

/// Buses a pintar, y qué buses quedaron dentro del radio (el estado que hace
/// falta recordar para la histéresis de la próxima vuelta).
typedef VisibleBuses = ({List<BusPosition> buses, Set<String> withinRadius});

/// Recorta [positions] al radio alrededor de ([userLat], [userLon]).
///
/// - **Sin ubicación** no se recorta nada: no hay desde dónde medir, y un mapa
///   vacío sería peor que uno lleno. Es el estado del primer arranque, antes
///   de que el usuario ponga su pin.
/// - [alwaysVisible] (el bus seleccionado, los buses con aviso armado) se
///   pinta esté donde esté. Que un bus desaparezca del mapa mientras el
///   usuario tiene su ficha abierta, o mientras espera su aviso, es la peor
///   forma posible de ahorrar píxeles.
/// - [previouslyWithinRadius] son los que ya estaban dentro: a esos se les
///   aplica el radio de salida, más ancho.
VisibleBuses filterBusesByRadius({
  required List<BusPosition> positions,
  required double? userLat,
  required double? userLon,
  required Set<String> alwaysVisible,
  required Set<String> previouslyWithinRadius,
}) {
  if (userLat == null || userLon == null) {
    return (buses: positions, withinRadius: const <String>{});
  }

  final buses = <BusPosition>[];
  final withinRadius = <String>{};
  for (final bus in positions) {
    final distance = haversineMeters(userLat, userLon, bus.lat, bus.lon);
    final inside = distance <= visibleRadiusMeters ||
        (previouslyWithinRadius.contains(bus.busId) &&
            distance <= visibleRadiusExitMeters);
    if (inside) {
      withinRadius.add(bus.busId);
      buses.add(bus);
    } else if (alwaysVisible.contains(bus.busId)) {
      // Se pinta, pero no cuenta como "dentro": si el usuario lo deselecciona
      // o cancela su aviso, desaparece sin arrastrar el margen de salida.
      buses.add(bus);
    }
  }
  return (buses: buses, withinRadius: withinRadius);
}
