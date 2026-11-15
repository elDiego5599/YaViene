// Lo que el mapa dibuja de una opción del planificador
// (docs/viaje-completo.md, sección 3.3): la caminata punteada, solo aquí;
// el bus por su ruta, en el verde de siempre sobre su orla; y los puntos de
// subida y bajada. Sin MapLibre, para probarlo sin mapa.
import 'package:ya_viene_core/ya_viene_core.dart';

import '../map/presentation/utils/camera_fit.dart' show FitBounds;

class TrazoDelViaje {
  const TrazoDelViaje({
    required this.origen,
    required this.destino,
    required this.caminatas,
    required this.enBus,
    required this.subidas,
    required this.bajadas,
  });

  final GeoPoint origen;
  final GeoPoint destino;

  /// En línea recta, como se mide: no hay calles para medir la caminata.
  final List<List<GeoPoint>> caminatas;

  /// Cada tramo en bus por su ruta, en el sentido en que anda el bus.
  final List<List<GeoPoint>> enBus;
  final List<GeoPoint> subidas;
  final List<GeoPoint> bajadas;

  /// La caja de todo lo dibujado, para que la cámara lo enmarque.
  FitBounds get caja {
    final todos = [
      origen,
      destino,
      for (final l in caminatas) ...l,
      for (final l in enBus) ...l,
    ];
    var (minLat, maxLat) = (todos.first.lat, todos.first.lat);
    var (minLon, maxLon) = (todos.first.lon, todos.first.lon);
    for (final p in todos) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lon < minLon) minLon = p.lon;
      if (p.lon > maxLon) maxLon = p.lon;
    }
    return (minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon);
  }
}

/// El dibujo de [viaje]. Si su ruta ya no está en [red] (el catálogo cambió
/// entre planear y dibujar), el tramo va recto de la subida a la bajada en
/// vez de no dibujarse.
TrazoDelViaje trazarViaje(Viaje viaje, RedDeRutas red) {
  final rutas = {for (final r in red.rutas) r.id: r.medible};
  return TrazoDelViaje(
    origen: viaje.origen.punto,
    destino: viaje.destino.punto,
    caminatas: [
      for (final t in viaje.tramos)
        if (t is TramoAPie) [t.desde, t.hasta],
    ],
    enBus: [
      for (final t in viaje.enBus)
        rutas[t.ruta]?.trazoEntre(t.subida.avance, t.bajada.avance) ??
            [t.subida.punto, t.bajada.punto],
    ],
    subidas: [for (final t in viaje.enBus) t.subida.punto],
    bajadas: [for (final t in viaje.enBus) t.bajada.punto],
  );
}

List<double> _coord(GeoPoint p) => [p.lon, p.lat];

Map<String, dynamic> lineasAGeoJson(List<List<GeoPoint>> lineas) => {
      'type': 'FeatureCollection',
      'features': [
        for (final l in lineas)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': [for (final p in l) _coord(p)],
            },
            'properties': const <String, dynamic>{},
          },
      ],
    };

Map<String, dynamic> puntosAGeoJson(List<GeoPoint> puntos) => {
      'type': 'FeatureCollection',
      'features': [
        for (final p in puntos)
          {
            'type': 'Feature',
            'geometry': {'type': 'Point', 'coordinates': _coord(p)},
            'properties': const <String, dynamic>{},
          },
      ],
    };
