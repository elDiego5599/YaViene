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

  group('la ruta pasa dos veces cerca del punto: cuenta el paso más cerca', () {
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

    test('viniendo de lejos, el paso de enfrente cuenta hacia adelante', () {
      // El bus en x = 900 de la vuelta, rumbo oeste: 400 hasta x = 500 y 120
      // de desvío; hacia atrás, a la ida, serían 800 + 80.
      final s = SeguidorRuta(rect);
      expect(s.distancia(_bus(900, 200, rumbo: 270), _m(500, 80)),
          closeTo(520, 5));
    });

    test('antes de la esquina no hay otro paso: la ruta sigue acercándose', () {
      // El punto en (990, 100), junto a la subida por x = 1000. La ida le
      // queda a 100 en x = 990, pero de ahí la ruta se le acerca más: el
      // paso es la subida, a 10. Del bus en x = 900: 100 + 100 + 10.
      final s = SeguidorRuta(rect);
      expect(
          s.distancia(_bus(900, 0, rumbo: 90), _m(990, 100)), closeTo(210, 5));
    });

    test('fuera de la ruta cuenta el paso que trae el bus más cerca', () {
      // El punto en (500, 20): la vuelta le queda a 180, 160 más que la ida.
      // El bus en x = 300 de la vuelta pasó x = 500 hace 200 m: 200 + 180,
      // no la vuelta por la ida, 1020 (dueño, 2026-10-19: 15,6 km con el
      // bus a 2 km y el pin entre dos calles de la ruta).
      final s = SeguidorRuta(rect);
      expect(s.distancia(_bus(300, 200, rumbo: 270), _m(500, 20)),
          closeTo(380, 5));
    });

    test('sobre la ruta, la otra calle a 200 m también cuenta', () {
      // El punto en la ida (500, 0); el bus en la vuelta, x = 300, a 200
      // de pasarle enfrente: 200 + 200, no 1000 por la ida.
      final s = SeguidorRuta(rect);
      expect(
          s.distancia(_bus(300, 200, rumbo: 270), _m(500, 0)), closeTo(400, 5));
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

    test('bus a más de 60 m de la ruta', () {
      final s = SeguidorRuta(idaYVuelta);
      final bus = _bus(500, 80, rumbo: 90);
      expect(s.avanceDe(bus), isNull);
      expect(s.distancia(bus, _m(200, 0)), isNull);
    });

    test('punto a más de 300 m de la ruta', () {
      final s = SeguidorRuta(idaYVuelta);
      expect(s.distancia(_bus(500, 0, rumbo: 90), _m(200, 400)), isNull);
    });
  });
}
