// Las rutas juntas, como red: por dónde pasa cada una y dónde se puede
// cambiar de una a otra.
import 'dart:math' as math;

import '../geo/por_ruta.dart';
import '../models/route_trajectory.dart';

/// Una ruta de la red: su recorrido listo para medir y quién la opera.
class RutaDeLaRed {
  const RutaDeLaRed({
    required this.id,
    required this.empresa,
    required this.medible,
  });

  /// El `routeId`.
  final String id;

  /// El `companyId` de la empresa que la opera.
  final String empresa;
  final RutaMedible medible;
}

/// Un sitio donde se puede cambiar de una ruta a otra: se baja de la
/// primera en el avance [baja], se caminan [caminata] metros y se sube a
/// la segunda en su avance [sube].
typedef Cambio = ({double baja, double sube, double caminata});

/// Las rutas entre las que se planea un viaje.
///
/// Dónde se cruzan dos rutas no depende de quién busca: se calcula una
/// vez, al armar la red, y cada búsqueda solo lo lee.
class RedDeRutas {
  /// [caminataDeTransbordo] es lo más que se camina de un bus a otro: 150 m,
  /// una cuadra larga o cruzar una avenida. Más lejos ya no es un cambio de
  /// bus, es otra caminata.
  RedDeRutas(Iterable<RutaDeLaRed> rutas, {this.caminataDeTransbordo = 150})
      : rutas = List.unmodifiable(rutas) {
    _buscarCambios();
  }

  final List<RutaDeLaRed> rutas;
  final double caminataDeTransbordo;
  final _cambios = <int, List<Cambio>>{};

  /// Cada cuánto se mira una ruta para ver qué otras pasan cerca. Un cruce
  /// en ángulo recto se ve desde [caminataDeTransbordo] a cada lado, así
  /// que con 50 m no se escapa ninguno.
  static const double _paso = 50;

  /// Dónde se puede cambiar de la ruta en el índice [de] a la del índice
  /// [a], en el orden en que la primera pasa por esos sitios. Donde las dos
  /// van juntas hay uno cada [_paso] metros.
  List<Cambio> cambios(int de, int a) =>
      _cambios[de * rutas.length + a] ?? const [];

  /// Recorre cada ruta de a [_paso] metros y, con una rejilla que dice qué
  /// rutas pasan por cada celda, mira solo las que tiene cerca: comparar
  /// cada muestra con cada tramo de las demás rutas son 50 millones de
  /// proyecciones con las 15 de Barranquilla.
  void _buscarCambios() {
    if (rutas.length < 2) return;
    // La celda cubre la caminata más un paso: toda ruta a menos de la
    // caminata tiene una muestra en la celda del punto o en una vecina.
    final lado = caminataDeTransbordo + _paso;
    final gradosLat = lado / 111320;
    final gradosLon = lado /
        (111320 * math.cos(rutas.first.medible.puntoEn(0).lat * math.pi / 180));
    (int, int) celdaDe(GeoPoint p) =>
        ((p.lat / gradosLat).floor(), (p.lon / gradosLon).floor());

    final muestras = <List<({double avance, GeoPoint punto})>>[];
    final rejilla = <(int, int), List<({int ruta, double avance})>>{};
    for (var r = 0; r < rutas.length; r++) {
      final medible = rutas[r].medible;
      final deLaRuta = [
        for (var a = 0.0; a < medible.largo; a += _paso)
          (avance: a, punto: medible.puntoEn(a)),
        // En la circular, el final es el inicio otra vez.
        if (!medible.circular)
          (avance: medible.largo, punto: medible.puntoEn(medible.largo)),
      ];
      muestras.add(deLaRuta);
      for (final m in deLaRuta) {
        (rejilla[celdaDe(m.punto)] ??= []).add((ruta: r, avance: m.avance));
      }
    }

    for (var de = 0; de < rutas.length; de++) {
      final vistos = <int, Set<(int, int)>>{};
      for (final muestra in muestras[de]) {
        final (fila, columna) = celdaDe(muestra.punto);
        final cerca = <int, List<double>>{};
        for (var f = fila - 1; f <= fila + 1; f++) {
          for (var c = columna - 1; c <= columna + 1; c++) {
            for (final otra in rejilla[(f, c)] ?? const []) {
              if (otra.ruta != de) (cerca[otra.ruta] ??= []).add(otra.avance);
            }
          }
        }
        cerca.forEach((a, avances) {
          avances.sort();
          // Las muestras seguidas son un mismo paso de la otra ruta; un
          // salto es otro paso (su otro carril, o que vuelve por ahí).
          var inicio = avances.first, fin = avances.first;
          void cerrar() {
            final cambio = _cambio(
              rutas[de].medible,
              muestra.avance,
              muestra.punto,
              rutas[a].medible,
              inicio - _paso,
              fin + _paso,
            );
            if (cambio == null) return;
            // Cerca de un cruce varias muestras caen en el mismo sitio.
            final sitio = (cambio.baja.round(), cambio.sube.round());
            if ((vistos[a] ??= {}).add(sitio)) {
              (_cambios[de * rutas.length + a] ??= []).add(cambio);
            }
          }

          for (final avance in avances.skip(1)) {
            if (avance - fin > 2 * _paso) {
              cerrar();
              inicio = avance;
            }
            fin = avance;
          }
          cerrar();
        });
      }
    }
  }

  /// El cambio de [de], en su [avance] (el [punto]), al paso de [a] que
  /// queda entre [desde] y [hasta], o null si hay que caminar más de la
  /// cuenta.
  ///
  /// La muestra cae donde cae, hasta a medio paso del cruce de verdad: se
  /// afina una vez, llevando el punto de la otra ruta de vuelta a esta. En
  /// un cruce eso da la esquina, con cero metros a pie; donde van juntas
  /// no cambia nada.
  Cambio? _cambio(RutaMedible de, double avance, GeoPoint punto, RutaMedible a,
      double desde, double hasta) {
    var baja = avance;
    var sube = a.proyectarEntre(punto, desde, hasta);
    if (sube.desvio > 1) {
      final afinada = de.proyectarEntre(
          a.puntoEn(sube.avance), avance - _paso, avance + _paso);
      final desdeAhi =
          a.proyectarEntre(de.puntoEn(afinada.avance), desde, hasta);
      if (desdeAhi.desvio < sube.desvio) {
        baja = afinada.avance;
        sube = desdeAhi;
      }
    }
    if (sube.desvio > caminataDeTransbordo) return null;
    return (baja: baja, sube: sube.avance, caminata: sube.desvio);
  }
}
