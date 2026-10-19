// Qué rectángulo tiene que enmarcar la cámara del mapa.
//
// Antes se enmarcaba el recorrido completo de la ruta. Las rutas del área
// metropolitana miden ~16 x 11 km y su caja está centrada unos 5 km al sur
// del centro de Barranquilla —bajan hasta Ciudad Mallorquín—, así que elegir
// ruta echaba la cámara fuera de la ciudad y a un zoom donde no se distingue
// nada. Ahora se enmarca lo que está vivo: los buses y el punto de espera.

import 'package:ya_viene_core/ya_viene_core.dart' show AppMotion;

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

/// Caja centrada en el punto de espera, del lado mínimo.
///
/// Enmarcar "todo lo vivo" tiene un efecto secundario feo: basta un bus en el
/// otro extremo de la ruta para que la caja abarque media ciudad, y entonces
/// el pin —lo único que el usuario reconoce en el mapa— queda de mota en una
/// esquina. Cuando hay punto de espera, el encuadre es el punto de espera; los
/// buses ya se ven llegar hacia él.
FitBounds waitingPointBounds(
  double lat,
  double lon, {
  double spanDeg = minFitSpanDeg,
}) {
  return liveViewportBounds(
    [(lat: lat, lon: lon)],
    minSpanDeg: spanDeg,
  )!;
}

/// Caja del aviso que se tocó: el bus y el punto de espera juntos.
///
/// El aviso sonó porque el bus está cerca, así que caben los dos sin que el
/// pin se vuelva una mota. Devuelve `null` mientras el mapa siga en otra
/// ruta ([rutaEnMapa] distinta de [rutaDelAviso]) o el bus no haya llegado
/// en un lote: el pedido espera al siguiente.
FitBounds? avisoBounds({
  required String rutaDelAviso,
  required String? rutaEnMapa,
  required FitPoint? bus,
  FitPoint? espera,
}) {
  if (rutaEnMapa != rutaDelAviso || bus == null) return null;
  return liveViewportBounds([bus, if (espera != null) espera]);
}

/// Lo que tarda la cámara en llegar al bus tocado.
const Duration kViajeCamara = Duration(milliseconds: 600);

/// Dónde va la cámara a [t] de empezar el viaje de [desde] a [hasta].
///
/// Con `AppMotion.curvaCambio`, el resorte sin rebote: arranca quieta, va
/// rápido al principio y se posa en el bus sin pasarse.
FitPoint puntoDelViaje(FitPoint desde, FitPoint hasta, Duration t) {
  final g = AppMotion.curvaCambio.transform(
      (t.inMicroseconds / kViajeCamara.inMicroseconds).clamp(0.0, 1.0));
  return (
    lat: desde.lat + (hasta.lat - desde.lat) * g,
    lon: desde.lon + (hasta.lon - desde.lon) * g,
  );
}
