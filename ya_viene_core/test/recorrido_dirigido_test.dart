// El viaje va en el sentido de la ruta: el bus no se devuelve. Estas
// pruebas dibujan rutas en metros y esperan cifras que salen del dibujo.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/core/geo/por_ruta.dart';
import 'package:ya_viene_core/core/models/route_trajectory.dart';

const _lat0 = 10.98;
const _lon0 = -74.80;

GeoPoint _m(double x, double y) => GeoPoint(
      lat: _lat0 + y / 111320,
      lon: _lon0 + x / (111320 * math.cos(_lat0 * math.pi / 180)),
    );

/// 1 km hacia el este.
final _recta = RutaMedible.de([_m(0, 0), _m(1000, 0)])!;

/// Un cuadrado de 400 m de lado, 1.600 m de vuelta, que cierra donde abre.
final _circular = RutaMedible.de([
  _m(0, 0),
  _m(400, 0),
  _m(400, 400),
  _m(0, 400),
  _m(0, 0),
])!;

/// Ida por una calle y vuelta por la paralela, a 100 m: 2.100 m.
final _idaYVuelta = RutaMedible.de([
  _m(0, 0),
  _m(1000, 0),
  _m(1000, 100),
  _m(0, 100),
])!;

void main() {
  group('recorridoDirigido', () {
    test('hacia adelante son los metros entre los dos avances', () {
      expect(_recta.recorridoDirigido(200, 700), closeTo(500, 1e-9));
    });

    test('hacia atrás no hay viaje: el bus no se devuelve', () {
      expect(_recta.recorridoDirigido(700, 200), isNull);
    });

    test('subir y bajar en el mismo punto son cero metros', () {
      expect(_recta.recorridoDirigido(300, 300), 0);
      expect(_circular.recorridoDirigido(300, 300), 0);
    });

    test('en la circular, hacia atrás es dar la vuelta', () {
      expect(_circular.recorridoDirigido(100, 300), closeTo(200, 1));
      expect(_circular.recorridoDirigido(300, 100), closeTo(1400, 1));
      expect(_circular.recorridoDirigido(1500, 100), closeTo(200, 1));
    });

    test('nunca es negativo ni pasa de la vuelta entera', () {
      final azar = math.Random(7);
      for (final ruta in [_recta, _circular, _idaYVuelta]) {
        for (var i = 0; i < 500; i++) {
          final d = ruta.recorridoDirigido(
            azar.nextDouble() * ruta.largo,
            azar.nextDouble() * ruta.largo,
          );
          if (d == null) continue;
          expect(d, greaterThanOrEqualTo(0));
          expect(d, lessThan(ruta.largo));
        }
      }
    });
  });

  group('pasosCerca', () {
    test('en ida y vuelta por calles paralelas da los dos pasos', () {
      final pasos = _idaYVuelta.pasosCerca(_m(500, 40), 100);
      expect(pasos, hasLength(2));
      expect(pasos[0].avance, closeTo(500, 2));
      expect(pasos[0].desvio, closeTo(40, 2));
      expect(pasos[1].avance, closeTo(1600, 2));
      expect(pasos[1].desvio, closeTo(60, 2));
    });

    test('lo que queda más lejos que el tope no cuenta', () {
      final pasos = _idaYVuelta.pasosCerca(_m(500, 40), 50);
      expect(pasos, hasLength(1));
      expect(pasos.single.avance, closeTo(500, 2));
      expect(_idaYVuelta.pasosCerca(_m(500, 900), 600), isEmpty);
    });
  });

  test('puntoEn devuelve el punto de la ruta en ese avance', () {
    final p = _idaYVuelta.puntoEn(1600);
    final esperado = _m(500, 100);
    expect(p.lat, closeTo(esperado.lat, 1e-6));
    expect(p.lon, closeTo(esperado.lon, 1e-6));
  });
}
