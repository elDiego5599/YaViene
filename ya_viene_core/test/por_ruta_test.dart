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

double _faltan(DistanciaPorRuta? d) => (d! as Faltan).metros;

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
    expect(_faltan(s.distancia(bus, _m(200, 4))), closeTo(304, 5));
  });

  test('ida y vuelta: yendo al este, ya pasó a la persona', () {
    final s = SeguidorRuta(idaYVuelta);
    final bus = _bus(500, 2, rumbo: 90);
    expect(s.avanceDe(bus), closeTo(500, 5));
    expect(s.distancia(bus, _m(200, 4)), isA<YaPaso>());
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
    expect(_faltan(s.distancia(bus, _m(0, 400))), closeTo(3400, 5));
  });

  test('ruta abierta: un punto que el bus ya dejó atrás es «ya pasó»', () {
    final u =
        RutaMedible.de([_m(0, 0), _m(1500, 0), _m(1500, 400), _m(0, 400)])!;
    final s = SeguidorRuta(u);
    expect(
        s.distancia(_bus(750, 400, rumbo: 270), _m(1500, 200)), isA<YaPaso>());
  });

  group('circular: pasar del final al inicio no es retroceder', () {
    // Cuadrado de 500 m que acaba en (0, 10): cierra con 10 m, 2000 m.
    final cuadrado = RutaMedible.de(
        [_m(0, 0), _m(500, 0), _m(500, 500), _m(0, 500), _m(0, 10)])!;

    test('a 20 m del final, un punto a 100 m del inicio queda a 120 m', () {
      final s = SeguidorRuta(cuadrado);
      final bus = _bus(0, 20, rumbo: 180);
      expect(s.avanceDe(bus), closeTo(1980, 5));
      expect(_faltan(s.distancia(bus, _m(100, 0))), closeTo(120, 5));
    });

    test('el bus que cruza el inicio sigue contando hacia adelante', () {
      final s = SeguidorRuta(cuadrado);
      s.avanceDe(_bus(0, 20, rumbo: 180));
      final bus = _bus(20, 0, segundos: 3);
      expect(s.avanceDe(bus), closeTo(20, 5));
      expect(_faltan(s.distancia(bus, _m(100, 0))), closeTo(80, 5));
      // Y lo que dejó a 30 m, justo antes del final, ya pasó.
      expect(s.distancia(bus, _m(0, 10)), isA<YaPaso>());
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
