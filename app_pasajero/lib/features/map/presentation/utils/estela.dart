// La estela del bus en el mapa: un rastro tenue de por dónde viene, que se
// apaga hacia atrás (dueño, 2026-10-19).
//
// MapLibre de Flutter no trae `line-gradient`, así que el apagado se hace
// con capas: [kCapasEstela] líneas que terminan todas en el bus, cada una
// más corta, con la misma opacidad. Donde se pisan todas, junto al bus, se
// ve más; la más larga se queda sola en la cola.

import 'package:ya_viene_core/ya_viene_core.dart';

import 'geo.dart';

/// Cuánto rastro deja el bus detrás.
const double kLargoEstela = 200;

/// Cuántas capas apagan la estela hacia atrás.
const int kCapasEstela = 4;

/// Más que esto entre dos fijaciones es un salto (se perdió la señal, otra
/// vuelta): unirlas con una recta dibujaría una calle que no existe.
const double kSaltoEstela = 300;

double _metros(GeoPoint a, GeoPoint b) =>
    haversineMeters(a.lat, a.lon, b.lat, b.lon);

/// [historia] con [nuevo] al final, sin lo que quede más atrás de
/// [kLargoEstela] salvo el punto del borde. Tras un salto, solo [nuevo].
List<GeoPoint> sumarAEstela(List<GeoPoint> historia, GeoPoint nuevo) {
  if (historia.isNotEmpty && _metros(historia.last, nuevo) > kSaltoEstela) {
    return [nuevo];
  }
  final puntos = [...historia, nuevo];
  var recorrido = 0.0;
  for (var i = puntos.length - 1; i > 0; i--) {
    recorrido += _metros(puntos[i - 1], puntos[i]);
    if (recorrido >= kLargoEstela) return puntos.sublist(i - 1);
  }
  return puntos;
}

/// Las capas de la estela de [puntos] (del más viejo al bus), de la más
/// larga a la más corta. Una estela de menos de [kLargoEstela] se reparte
/// igual, para que también se apague.
List<List<GeoPoint>> capasDeEstela(List<GeoPoint> puntos) {
  if (puntos.length < 2) return const [];
  // Del bus hacia atrás, con lo recorrido hasta cada punto.
  final atras = puntos.reversed.toList();
  final acumulado = [0.0];
  for (var i = 1; i < atras.length; i++) {
    acumulado.add(acumulado.last + _metros(atras[i - 1], atras[i]));
  }
  final total = acumulado.last.clamp(0.0, kLargoEstela);
  if (total <= 0) return const [];

  List<GeoPoint> hasta(double largo) {
    final linea = [atras.first];
    for (var i = 1; i < atras.length; i++) {
      if (acumulado[i] < largo) {
        linea.add(atras[i]);
        continue;
      }
      final tramo = acumulado[i] - acumulado[i - 1];
      final f = tramo == 0 ? 0.0 : (largo - acumulado[i - 1]) / tramo;
      final a = atras[i - 1];
      final b = atras[i];
      linea.add(GeoPoint(
          lat: a.lat + (b.lat - a.lat) * f, lon: a.lon + (b.lon - a.lon) * f));
      break;
    }
    return linea.reversed.toList();
  }

  return [
    for (var k = kCapasEstela; k >= 1; k--) hasta(total * k / kCapasEstela),
  ];
}
