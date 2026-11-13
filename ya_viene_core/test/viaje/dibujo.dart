// Rutas dibujadas en metros para las pruebas del viaje: las cifras que se
// esperan salen del dibujo, no de correr el código.
import 'dart:math' as math;

import 'package:ya_viene_core/ya_viene_core.dart';

const _lat0 = 10.98;
const _lon0 = -74.80;

/// El punto a [x] metros al este y [y] al norte del origen del dibujo.
GeoPoint m(double x, double y) => GeoPoint(
      lat: _lat0 + y / 111320,
      lon: _lon0 + x / (111320 * math.cos(_lat0 * math.pi / 180)),
    );

Lugar lugar(double x, double y) =>
    Lugar(punto: m(x, y), origen: OrigenLugar.pin);

RutaDeLaRed ruta(String id, List<GeoPoint> puntos, {String empresa = 'EMP'}) =>
    RutaDeLaRed(id: id, empresa: empresa, medible: RutaMedible.de(puntos)!);

/// 4 km hacia el este por y = 0.
RutaDeLaRed recta([String id = 'RECTA']) => ruta(id, [m(0, 0), m(4000, 0)]);

/// Ida por y = 0 y vuelta por la paralela, a 100 m: 4.100 m.
RutaDeLaRed idaYVuelta() => ruta('IDA-VUELTA', [
      m(0, 0),
      m(2000, 0),
      m(2000, 100),
      m(0, 100),
    ]);

/// Un cuadrado de 3 km de lado, 12 km de vuelta, que cierra donde abre:
/// este por y = 0, norte por x = 3000, oeste por y = 3000 y sur por x = 0.
RutaDeLaRed circular() => ruta('CIRCULAR', [
      m(0, 0),
      m(3000, 0),
      m(3000, 3000),
      m(0, 3000),
      m(0, 0),
    ]);

/// Sube de sur a norte por x = 2000 y cruza a [recta] en (2000, 0), a
/// 2 km de su inicio.
RutaDeLaRed cruce() => ruta('CRUCE', [m(2000, -2000), m(2000, 2000)]);

/// Corre junto a [recta] (a 10 m) de x = 1000 a x = 3000 y ahí dobla al
/// norte.
RutaDeLaRed junta() => ruta('JUNTA', [
      m(1000, 10),
      m(3000, 10),
      m(3000, 3000),
    ]);

BusPosition bus(
  String id,
  String rutaId,
  double x,
  double y, {
  double? rumbo,
  bool sinSenal = false,
  int segundos = 0,
}) =>
    BusPosition(
      busId: id,
      routeId: rutaId,
      lat: m(x, y).lat,
      lon: m(x, y).lon,
      heading: rumbo,
      speedKmh: 30,
      // [segundos] después: una posición igual de vieja no mueve al bus.
      timestamp: DateTime(2026, 11, 13, 10, 0, segundos),
      isGhostBus: sinSenal,
    );
