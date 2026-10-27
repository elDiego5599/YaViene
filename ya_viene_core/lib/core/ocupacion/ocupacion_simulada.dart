import 'dart:math' as math;

import '../geo/por_ruta.dart';
import '../models/bus_position.dart';

/// FNV-1a de 32 bits: `String.hashCode` no promete ser el mismo entre
/// ejecuciones, y el ejemplo tiene que serlo (como en la ocupación del
/// panel, `ocupacion_provider.dart`).
int _hash(String texto) {
  var h = 0x811c9dc5;
  for (final c in texto.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// De 0 a 1, fijo para cada texto. FNV-1a mezcla mal la última letra:
/// BUS-SQA220 y BUS-SQA221 salían con el mismo desfase y subían y bajaban
/// juntos. El remate de MurmurHash3 reparte ese último cambio por todo el
/// número.
double _azar(String texto) {
  var h = _hash(texto);
  h = ((h ^ (h >> 16)) * 0x85ebca6b) & 0xffffffff;
  h = ((h ^ (h >> 13)) * 0xc2b2ae35) & 0xffffffff;
  return (h ^ (h >> 16)) / 0xffffffff;
}

double _campana(double h, double centro, double ancho) =>
    math.exp(-math.pow(h - centro, 2) / (2 * ancho * ancho));

/// Ocupación de ejemplo del bus [busId], en %, en el [tramo] de su ruta
/// (0 a 1, lo recorrido sobre el largo) a la [hora] local. Ningún bus tiene
/// aún cámara de aforo (`YaVieneBackend/prototipo-aforo`): cuando la tenga,
/// el dato llega del bus y esto se va.
///
/// Sube y baja por tramos a lo largo de toda la ruta (dueño, 2026-10-27):
/// la mitad es de la ruta (donde se sube la gente, igual para todos sus
/// buses, dos veces por vuelta) y la otra mitad de cada bus (tres veces por
/// vuelta, con su propio desfase), así que en el mismo tramo a uno le sube
/// y a otro le baja. Las ondas dan vueltas enteras: la vuelta cierra sin
/// salto. La hora la escala: llena de 6 a 8 y de 4 a 7, suelta de noche.
int ocupacionSimulada({
  required String busId,
  required String routeId,
  required double tramo,
  required DateTime hora,
}) {
  final h = hora.hour + hora.minute / 60;
  final dia = (0.25 +
          0.65 * _campana(h, 7, 1.3) +
          0.2 * _campana(h, 12.5, 0.9) +
          0.6 * _campana(h, 17.5, 1.5))
      .clamp(0.15, 1.0);
  double onda(int vueltas, String semilla) =>
      0.5 + 0.5 * math.sin(2 * math.pi * (vueltas * tramo + _azar(semilla)));
  final mezcla = 0.45 * onda(2, 'ruta $routeId') + 0.55 * onda(3, 'bus $busId');
  return (100 * dia * (0.2 + 0.8 * mezcla)).round().clamp(0, 100);
}

/// La ocupación de [bus] en el tramo por donde va, a la hora de su
/// posición; null sin ruta o con el bus fuera de ella: sin tramo no hay qué
/// decir. La hora es la de la posición y no la del reloj: la cifra cambia
/// cuando el bus se mueve, no sola. La comparten la tarjeta del bus del
/// pasajero y la ficha del bus del panel.
int? ocupacionEnRuta(SeguidorRuta? seguidor, BusPosition bus) {
  if (seguidor == null || seguidor.ruta.largo <= 0) return null;
  final avance = seguidor.avanceDe(bus);
  if (avance == null) return null;
  return ocupacionSimulada(
    busId: bus.busId,
    routeId: bus.routeId,
    tramo: avance / seguidor.ruta.largo,
    hora: bus.timestamp.toLocal(),
  );
}
