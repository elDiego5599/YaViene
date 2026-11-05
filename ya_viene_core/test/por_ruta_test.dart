import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

// Las rutas de prueba se dibujan en metros sobre Barranquilla y se pasan a
// grados con la misma cuenta de un mapa plano: a esta escala el error es
// menor que la tolerancia de 5 m. Las cifras esperadas salen del dibujo, a
// mano, no del código.
const _lat0 = 10.98;
const _lon0 = -74.80;

GeoPoint _m(double x, double y) => GeoPoint(
      lat: _lat0 + y / 111320,
      lon: _lon0 + x / (111320 * math.cos(_lat0 * math.pi / 180)),
    );

var _reloj = DateTime.utc(2026, 10, 8, 12);

BusPosition _bus(double x, double y, {double? rumbo, int segundos = 0}) {
  _reloj = _reloj.add(Duration(seconds: segundos));
  final p = _m(x, y);
  return BusPosition(
    busId: 'B1',
    routeId: 'R-1',
    lat: p.lat,
    lon: p.lon,
    heading: rumbo,
    speedKmh: 30,
    timestamp: _reloj,
    isGhostBus: false,
  );
}

void main() {
  // Ida por y = 0 y vuelta por y = 8: la misma calle, un carril por
  // sentido. Circular (cierra a 8 m): 1000 + 8 + 1000 + 8 = 2016 m.
  final idaYVuelta =
      RutaMedible.de([_m(0, 0), _m(1000, 0), _m(1000, 8), _m(0, 8)])!;

  test('ida y vuelta por la misma calle: el rumbo del bus decide el carril',
      () {
    // A 2 m de la ida y a 6 de la vuelta, pero va al oeste: vuelta.
    final s = SeguidorRuta(idaYVuelta);
    final bus = _bus(500, 2, rumbo: 270);
    expect(s.avanceDe(bus), closeTo(1508, 5));
    // La persona en (200, 4): la vuelta le pasa en el avance 1808.
    expect(s.distancia(bus, _m(200, 4)), closeTo(304, 5));
  });

  test('ida y vuelta: yendo al este, ya pasó a 300 m: dice 300', () {
    // Ya pasó por la persona: lo que hay es la distancia por la ruta hacia
    // atrás, no la vuelta hasta el próximo paso (dueño, 2026-10-19: decía
    // 20 km con el bus a la vista). Del 500 al 200 de la ida, más 4.
    final s = SeguidorRuta(idaYVuelta);
    final bus = _bus(500, 2, rumbo: 90);
    expect(s.avanceDe(bus), closeTo(500, 5));
    expect(s.distancia(bus, _m(200, 4)), closeTo(304, 5));
  });

  test('dos buses lado a lado, uno de ida y otro de vuelta, dicen lo mismo',
      () {
    // La ida va por y = 0 hasta x = 2000, sube, vuelve por arriba y baja a
    // la vuelta por y = 8 desde x = 1000. La persona en (1800, 0) solo la
    // pasa la ida. El bus de la vuelta en x = 500 está al lado del de la
    // ida: por la ruta desde su carril serían 2,3 km, la vuelta que le
    // falta; pero está en la misma calle que el otro, a 1,3 km (dueño,
    // 2026-10-19: 10 y 29 km con los dos buses juntos).
    final ruta = RutaMedible.de([
      _m(0, 0), _m(2000, 0), _m(2000, 1000), _m(1000, 1000), //
      _m(1000, 8), _m(0, 8),
    ])!;
    final s = SeguidorRuta(ruta);
    final ida = _bus(500, 0, rumbo: 90);
    final vuelta = _bus(500, 8, rumbo: 270);
    expect(s.distancia(ida, _m(1800, 0)), closeTo(1300, 5));
    expect(SeguidorRuta(ruta).distancia(vuelta, _m(1800, 0)), closeTo(1300, 5));
  });

  test('con avance previo solo busca en la ventana: no salta de carril', () {
    final s = SeguidorRuta(idaYVuelta);
    expect(s.avanceDe(_bus(400, 0, rumbo: 90)), closeTo(400, 5));
    // Sin rumbo y más cerca de la vuelta (3 m) que de la ida (5 m): sin
    // ventana caería en la vuelta, avance 1508.
    expect(s.avanceDe(_bus(500, 5, segundos: 4)), closeTo(500, 5));
  });

  test('400 m en línea recta son 3,4 km por la ruta', () {
    // Una U abierta: este 1500 m, norte 400 m, oeste 1500 m.
    final u =
        RutaMedible.de([_m(0, 0), _m(1500, 0), _m(1500, 400), _m(0, 400)])!;
    final s = SeguidorRuta(u);
    final bus = _bus(0, 0, rumbo: 90);
    expect(s.distancia(bus, _m(0, 400)), closeTo(3400, 5));
  });

  test('ruta abierta: el punto que el bus ya dejó atrás se mide hacia atrás',
      () {
    // Del avance 2650 (x = 750 de la vuelta) al 1700 (la subida, y = 200).
    final u =
        RutaMedible.de([_m(0, 0), _m(1500, 0), _m(1500, 400), _m(0, 400)])!;
    final s = SeguidorRuta(u);
    expect(s.distancia(_bus(750, 400, rumbo: 270), _m(1500, 200)),
        closeTo(950, 5));
  });

  group('circular: pasar del final al inicio no es retroceder', () {
    // Cuadrado de 500 m que acaba en (0, 10): cierra con 10 m, 2000 m.
    final cuadrado = RutaMedible.de(
        [_m(0, 0), _m(500, 0), _m(500, 500), _m(0, 500), _m(0, 10)])!;

    test('a 20 m del final, un punto a 100 m del inicio queda a 120 m', () {
      final s = SeguidorRuta(cuadrado);
      final bus = _bus(0, 20, rumbo: 180);
      expect(s.avanceDe(bus), closeTo(1980, 5));
      expect(s.distancia(bus, _m(100, 0)), closeTo(120, 5));
    });

    test('el bus que cruza el inicio sigue contando hacia adelante', () {
      final s = SeguidorRuta(cuadrado);
      s.avanceDe(_bus(0, 20, rumbo: 180));
      final bus = _bus(20, 0, segundos: 3);
      expect(s.avanceDe(bus), closeTo(20, 5));
      expect(s.distancia(bus, _m(100, 0)), closeTo(80, 5));
      // Y lo que dejó atrás, antes del final, se cuenta hacia atrás
      // cruzando el inicio: de 20 a 1940, 80 m.
      expect(s.distancia(bus, _m(0, 60)), closeTo(80, 5));
    });
  });

  group('la persona espera en el punto de la ruta más cerca de su pin', () {
    // Rectángulo circular de 1000 × 200: este por y = 0, norte, oeste por
    // y = 200 y bajada al inicio. 2400 m.
    final rect = RutaMedible.de(
        [_m(0, 0), _m(1000, 0), _m(1000, 200), _m(0, 200), _m(0, 10)])!;

    test('pasado el paso más cercano, cuenta lo que lo dejó atrás', () {
      // El punto en (500, 80): a 80 m de la ida y a 120 de la vuelta. El bus
      // en x = 700 de la ida lo pasó hace 200 m: 200 + 80, ni el paso de
      // enfrente (1120) ni la vuelta entera.
      final s = SeguidorRuta(rect);
      expect(
          s.distancia(_bus(700, 0, rumbo: 90), _m(500, 80)), closeTo(280, 5));
    });

    test('viniendo por la otra calle, cuenta hasta la de su pin', () {
      // El punto en (500, 80): la ida a 80, la vuelta a 120. Espera en la
      // ida. El bus en x = 900 de la vuelta, rumbo oeste: hasta x = 500 de
      // la ida, hacia atrás, 800, más 80 (dueño, 2026-11-04: contar la
      // calle de enfrente hacía saltar la cifra con mover el pin un poco).
      final s = SeguidorRuta(rect);
      expect(s.distancia(_bus(900, 200, rumbo: 270), _m(500, 80)),
          closeTo(880, 5));
    });

    test('antes de la esquina no hay otro paso: la ruta sigue acercándose', () {
      // El punto en (990, 100), junto a la subida por x = 1000. La ida le
      // queda a 100 en x = 990, pero de ahí la ruta se le acerca más: el
      // paso es la subida, a 10. Del bus en x = 900: 100 + 100 + 10.
      final s = SeguidorRuta(rect);
      expect(
          s.distancia(_bus(900, 0, rumbo: 90), _m(990, 100)), closeTo(210, 5));
    });

    test('el bus por la calle de enfrente da la vuelta hasta la del pin', () {
      // El punto en (500, 20): la ida a 20, la vuelta a 180. Espera en la
      // ida, x = 500 (avance 500). El bus en x = 300 de la vuelta (avance
      // 1900): 1000 por la ruta, cruzando el inicio, más 20. El mapa
      // dibuja la línea del pin a ese punto: quien espera en la otra
      // calle corre el pin hasta ella.
      final s = SeguidorRuta(rect);
      expect(s.distancia(_bus(300, 200, rumbo: 270), _m(500, 20)),
          closeTo(1020, 5));
    });

    test('sobre la ruta espera ahí, aunque la otra calle quede a 200 m', () {
      // El punto en la ida (500, 0); el bus en la vuelta, x = 300: 1000.
      final s = SeguidorRuta(rect);
      expect(s.distancia(_bus(300, 200, rumbo: 270), _m(500, 0)),
          closeTo(1000, 5));
    });

    test('a 400 m de la ruta: la ruta hasta su punto más la caminada', () {
      // Rectángulo de 1000 × 500 (3000 m). El punto en (500, -400): la ida
      // le queda a 400. El bus en x = 200 de la ida: 300 + 400, no la
      // línea recta de 500 (dueño, 2026-11-04: pasar de 300 a 301 m del
      // pin cambiaba la cifra de la ruta a la recta, hasta 19 km).
      final ancho = RutaMedible.de(
          [_m(0, 0), _m(1000, 0), _m(1000, 500), _m(0, 500), _m(0, 10)])!;
      final s = SeguidorRuta(ancho);
      expect(
          s.distancia(_bus(200, 0, rumbo: 90), _m(500, -400)), closeTo(700, 5));
    });

    test('el punto de espera es el de la ruta más cerca del pin', () {
      final espera = rect.puntoDeEspera(_m(500, 80));
      final esperado = _m(500, 0);
      expect(espera.lat, closeTo(esperado.lat, 1e-6));
      expect(espera.lon, closeTo(esperado.lon, 1e-6));
    });
  });

  group('pasado el punto nunca es la vuelta siguiente', () {
    // El bus parado en el punto: unos metros de error lo ponen detrás.
    test('circular: 10 m pasado el punto, a 10 m', () {
      final cuadrado = RutaMedible.de(
          [_m(0, 0), _m(500, 0), _m(500, 500), _m(0, 500), _m(0, 10)])!;
      final s = SeguidorRuta(cuadrado);
      expect(s.distancia(_bus(110, 0, rumbo: 90), _m(100, 0)), closeTo(10, 5));
    });

    test('abierta: 10 m pasado el punto, a 10 m', () {
      final u =
          RutaMedible.de([_m(0, 0), _m(1500, 0), _m(1500, 400), _m(0, 400)])!;
      final s = SeguidorRuta(u);
      expect(s.distancia(_bus(510, 0, rumbo: 90), _m(500, 0)), closeTo(10, 5));
    });

    test('circular: 60 m pasado, a 60 m y no a la vuelta entera', () {
      final cuadrado = RutaMedible.de(
          [_m(0, 0), _m(500, 0), _m(500, 500), _m(0, 500), _m(0, 10)])!;
      final s = SeguidorRuta(cuadrado);
      expect(s.distancia(_bus(160, 0, rumbo: 90), _m(100, 0)), closeTo(60, 5));
    });
  });

  group('null cuando no se sabe', () {
    test('ruta sin segmento', () {
      expect(RutaMedible.de(const []), isNull);
      expect(RutaMedible.de([_m(0, 0)]), isNull);
      expect(RutaMedible.de([_m(0, 0), _m(0, 0)]), isNull);
    });

    test('bus a más de 60 m de la ruta (el pin, lejos o cerca, sí se mide)',
        () {
      final s = SeguidorRuta(idaYVuelta);
      final bus = _bus(500, 80, rumbo: 90);
      expect(s.avanceDe(bus), isNull);
      expect(s.distancia(bus, _m(200, 0)), isNull);
    });
  });

  test('en las 15 rutas, mover el pin no hace saltar la cifra', () {
    // Pines cada 100 m hasta 1 km de cada ruta, con un bus a mitad de
    // recorrido. Entre dos pines vecinos la cifra cambia a lo sumo lo que
    // se movió su punto de espera por la ruta más lo que cambió la
    // caminada (100 m, el paso), con holgura para dos carriles de la misma
    // calle. Solo salta donde de verdad cambia dónde se espera: el pin a
    // mitad de camino entre dos calles de la ruta, o el otro carril que se
    // abre a más de 30 m del sitio de espera (o se acerca), y eso es poco.
    // Antes, en estas rutas, saltaba de 5,8 a 19,3 km (dueño, 2026-11-04).
    const paso = 100.0;
    final datos = jsonDecode(File('assets/data/rutas.json').readAsStringSync())
        as Map<String, dynamic>;
    final rutas = datos['rutas'] as List;
    expect(rutas, hasLength(15));
    for (final r in rutas.cast<Map<String, dynamic>>()) {
      final pts = [
        for (final w in (r['waypoints'] as List).cast<Map<String, dynamic>>())
          GeoPoint(
              lat: (w['lat'] as num).toDouble(),
              lon: (w['lon'] as num).toDouble())
      ];
      final ruta = RutaMedible.de(pts)!;
      final a = pts[pts.length ~/ 2], b = pts[pts.length ~/ 2 + 1];
      final kx = 111320 * math.cos(a.lat * math.pi / 180);
      final rumbo = math.atan2((b.lon - a.lon) * kx, (b.lat - a.lat) * 111320) *
          180 /
          math.pi;
      final bus = BusPosition(
        busId: 'B1',
        routeId: r['routeId'] as String,
        lat: (a.lat + b.lat) / 2,
        lon: (a.lon + b.lon) / 2,
        heading: (rumbo + 360) % 360,
        speedKmh: 20,
        timestamp: DateTime.utc(2026, 11, 4),
        isGhostBus: false,
      );
      final s = SeguidorRuta(ruta);
      double recta(GeoPoint p, GeoPoint q) =>
          math.sqrt(math.pow((p.lon - q.lon) * kx, 2) +
              math.pow((p.lat - q.lat) * 111320, 2));
      final lats = pts.map((p) => p.lat), lons = pts.map((p) => p.lon);
      final la0 = lats.reduce(math.min) - 0.01;
      final lo0 = lons.reduce(math.min) - 0.01;
      final dla = paso / 111320, dlo = paso / kx;
      final nla = ((lats.reduce(math.max) + 0.01 - la0) / dla).ceil();
      final nlo = ((lons.reduce(math.max) + 0.01 - lo0) / dlo).ceil();
      final cifra = <(int, int), double>{};
      final avance = <(int, int), double>{};
      final pasos = <(int, int), List<double>>{};
      double vuelta(double x, double y) {
        final d = (x - y).abs();
        return ruta.circular ? math.min(d, ruta.largo - d) : d;
      }

      bool mismoSitio(List<double> uno, List<double> otro) =>
          uno.length == otro.length &&
          uno.every((x) => otro.any((y) => vuelta(x, y) <= 3 * paso)) &&
          otro.every((y) => uno.any((x) => vuelta(x, y) <= 3 * paso));
      for (var i = 0; i < nla; i++) {
        for (var j = 0; j < nlo; j++) {
          final p = GeoPoint(lat: la0 + i * dla, lon: lo0 + j * dlo);
          if (!pts.any((v) => recta(v, p) < 1000)) continue;
          final d = s.distancia(bus, p);
          expect(d, isNotNull, reason: '${r['routeId']} sin cifra en $p');
          cifra[(i, j)] = d!;
          avance[(i, j)] = ruta.proyectar(p).avance;
          pasos[(i, j)] = ruta.pasosPorLaEspera(p);
        }
      }
      var pares = 0, otroCarril = 0;
      for (final MapEntry(key: (i, j), value: d) in cifra.entries) {
        for (final vecino in [(i + 1, j), (i, j + 1)]) {
          final dv = cifra[vecino];
          if (dv == null) continue;
          final corrido = vuelta(avance[(i, j)]!, avance[vecino]!);
          // El punto de espera cambió de calle: el salto es de verdad.
          if (corrido > 3 * paso) continue;
          pares++;
          final tope = corrido + paso + 50;
          // El otro carril entró o salió del sitio de espera.
          if (!mismoSitio(pasos[(i, j)]!, pasos[vecino]!)) {
            if ((d - dv).abs() > tope) otroCarril++;
            continue;
          }
          expect((d - dv).abs(), lessThanOrEqualTo(tope),
              reason: '${r['routeId']} entre $i,$j y $vecino');
        }
      }
      expect(otroCarril / pares, lessThan(0.03), reason: '${r['routeId']}');
    }
  });
}
