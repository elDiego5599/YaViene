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

  test('ida y vuelta: yendo al este, la persona lo espera a la vuelta', () {
    // No se sabe si la persona espera la ida o la vuelta (dueño,
    // 2026-10-08): se cuenta hasta el próximo paso. Del 500 de la ida al
    // 1000, 8 de giro y 800 de vuelta hasta x = 200, más 4 de desvío.
    final s = SeguidorRuta(idaYVuelta);
    final bus = _bus(500, 2, rumbo: 90);
    expect(s.avanceDe(bus), closeTo(500, 5));
    expect(s.distancia(bus, _m(200, 4)), closeTo(1312, 5));
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

  test('ruta abierta: un punto que el bus ya dejó atrás no se mide', () {
    final u =
        RutaMedible.de([_m(0, 0), _m(1500, 0), _m(1500, 400), _m(0, 400)])!;
    final s = SeguidorRuta(u);
    expect(s.distancia(_bus(750, 400, rumbo: 270), _m(1500, 200)), isNull);
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
      // Y lo que dejó 80 m atrás, antes del final, es la vuelta siguiente:
      // de 20 a 1940.
      expect(s.distancia(bus, _m(0, 60)), closeTo(1920, 5));
    });
  });

  group('la ruta pasa dos veces cerca del punto: cuenta el próximo paso', () {
    // Rectángulo circular de 1000 × 200: este por y = 0, norte, oeste por
    // y = 200 y bajada al inicio. 2400 m.
    final rect = RutaMedible.de(
        [_m(0, 0), _m(1000, 0), _m(1000, 200), _m(0, 200), _m(0, 10)])!;

    test('pasado el paso más cercano, el de enfrente viene antes', () {
      // El punto en (500, 80): a 80 m de la ida y a 120 de la vuelta. El bus
      // en x = 700 de la ida ya dejó atrás el paso de 80 (dueño, 2026-10-18:
      // decía 31,7 km con el bus a la vista). Faltan 300 + 200 + 500 de
      // ruta y 120 de desvío, no la vuelta entera.
      final s = SeguidorRuta(rect);
      expect(s.distancia(_bus(700, 0, rumbo: 90), _m(500, 80)),
          closeTo(1120, 5));
    });

    test('antes de la esquina no hay otro paso: la ruta sigue acercándose', () {
      // El punto en (990, 100), junto a la subida por x = 1000. La ida le
      // queda a 100 en x = 990, pero de ahí la ruta se le acerca más: el
      // paso es la subida, a 10. Del bus en x = 900: 100 + 100 + 10.
      final s = SeguidorRuta(rect);
      expect(s.distancia(_bus(900, 0, rumbo: 90), _m(990, 100)),
          closeTo(210, 5));
    });

    test('un paso a más de 150 m del más cercano ya no es el mismo sitio', () {
      // El punto en (500, 20): la vuelta le queda a 180, 160 más que la ida.
      // Esa calle es otra: se espera la ida de la vuelta siguiente.
      final s = SeguidorRuta(rect);
      expect(s.distancia(_bus(700, 0, rumbo: 90), _m(500, 20)),
          closeTo(2220, 5));
    });
  });

  group('el ruido del GPS no manda al bus a la vuelta siguiente', () {
    // El bus parado en el punto: unos metros de error lo ponen detrás, y
    // sin tolerancia faltaría una vuelta entera (o, en la abierta, nada).
    test('circular: 10 m pasado el punto, está ahí', () {
      final cuadrado = RutaMedible.de(
          [_m(0, 0), _m(500, 0), _m(500, 500), _m(0, 500), _m(0, 10)])!;
      final s = SeguidorRuta(cuadrado);
      expect(s.distancia(_bus(110, 0, rumbo: 90), _m(100, 0)), closeTo(0, 5));
    });

    test('abierta: 10 m pasado el punto, está ahí', () {
      final u =
          RutaMedible.de([_m(0, 0), _m(1500, 0), _m(1500, 400), _m(0, 400)])!;
      final s = SeguidorRuta(u);
      expect(s.distancia(_bus(510, 0, rumbo: 90), _m(500, 0)), closeTo(0, 5));
    });

    test('circular: 60 m pasado, ya es la vuelta siguiente', () {
      final cuadrado = RutaMedible.de(
          [_m(0, 0), _m(500, 0), _m(500, 500), _m(0, 500), _m(0, 10)])!;
      final s = SeguidorRuta(cuadrado);
      // 2000 de vuelta menos los 60 que ya anduvo.
      expect(
          s.distancia(_bus(160, 0, rumbo: 90), _m(100, 0)), closeTo(1940, 5));
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
