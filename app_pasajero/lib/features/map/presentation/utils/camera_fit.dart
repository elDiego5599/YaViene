// Qué rectángulo tiene que enmarcar la cámara del mapa.
//
// Antes se enmarcaba el recorrido completo de la ruta. Las rutas del área
// metropolitana miden ~16 x 11 km y su caja está centrada unos 5 km al sur
// del centro de Barranquilla —bajan hasta Ciudad Mallorquín—, así que elegir
// ruta echaba la cámara fuera de la ciudad y a un zoom donde no se distingue
// nada. Ahora se enmarca lo que está vivo: los buses y el punto de espera.

/// Un punto a enmarcar, sin depender de los tipos de MapLibre para que esto
/// se pueda probar sin mapa.
typedef FitPoint = ({double lat, double lon});

/// Caja resultante, en el mismo orden que la espera `LatLngBounds`.
typedef FitBounds = ({
  double minLat,
  double minLon,
  double maxLat,
  double maxLon,
});

/// Lado mínimo de la caja, en grados (~2,5 km).
///
/// Con un solo bus la caja es un punto y la cámara se iría a zoom de calle:
/// se ve el bus enorme y se pierde de vista dónde está respecto a la ciudad.
const double minFitSpanDeg = 0.0225;

/// Caja que contiene [points], nunca más estrecha que [minSpanDeg] de lado.
///
/// Devuelve `null` con la lista vacía: sin nada que enmarcar es mejor no
/// mover la cámara que saltar a ninguna parte.
FitBounds? liveViewportBounds(
  List<FitPoint> points, {
  double minSpanDeg = minFitSpanDeg,
}) {
  if (points.isEmpty) return null;

  var minLat = points.first.lat;
  var maxLat = points.first.lat;
  var minLon = points.first.lon;
  var maxLon = points.first.lon;
  for (final point in points) {
    if (point.lat < minLat) minLat = point.lat;
    if (point.lat > maxLat) maxLat = point.lat;
    if (point.lon < minLon) minLon = point.lon;
    if (point.lon > maxLon) maxLon = point.lon;
  }

  final faltaLat = minSpanDeg - (maxLat - minLat);
  if (faltaLat > 0) {
    minLat -= faltaLat / 2;
    maxLat += faltaLat / 2;
  }
  final faltaLon = minSpanDeg - (maxLon - minLon);
  if (faltaLon > 0) {
    minLon -= faltaLon / 2;
    maxLon += faltaLon / 2;
  }

  return (minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon);
}
