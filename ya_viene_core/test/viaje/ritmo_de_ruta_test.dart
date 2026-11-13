import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'dibujo.dart';

void main() {
  late RitmoDeRuta ritmo;

  setUp(() => ritmo = RitmoDeRuta(SeguidorRuta(recta().medible)));

  /// Un bus de la recta que anda a [metrosPorSegundo] durante [minutos],
  /// con una posición cada 10 s, desde x = [desde] y el segundo [inicio].
  void anda(
    String id,
    double metrosPorSegundo, {
    required int minutos,
    double desde = 0,
    int inicio = 0,
    bool simulado = false,
    RitmoDeRuta? en,
  }) {
    for (var s = 0; s <= minutos * 60; s += 10) {
      (en ?? ritmo).ver(bus(
        id,
        'RECTA',
        desde + metrosPorSegundo * s,
        0,
        segundos: inicio + s,
        simulado: simulado,
      ));
    }
  }

  Matcher rango(int desde, int hasta, {bool simulado = false}) =>
      isA<RangoDeLlegada>()
          .having((r) => r.desde.inSeconds, 'desde', closeTo(desde * 60, 2))
          .having((r) => r.hasta.inSeconds, 'hasta', closeTo(hasta * 60, 2))
          .having((r) => r.simulado, 'simulado', simulado);

  test('sin haber visto buses, no dice nada', () {
    expect(ritmo.paraRecorrer(1000), isNull);
  });

  test('con menos de seis minutos de buses andando, no dice nada', () {
    anda('B1', 5, minutos: 5);

    expect(ritmo.paraRecorrer(1000), isNull);
  });

  test('un bus parejo a 5 m/s recorre 3 km en 10 minutos', () {
    anda('B1', 5, minutos: 6);

    expect(ritmo.paraRecorrer(3000), rango(10, 10));
  });

  test('el rango va del ritmo de los minutos rápidos al de los lentos', () {
    anda('B1', 8, minutos: 3);
    anda('B1', 4, minutos: 3, desde: 1440, inicio: 180);

    // 2.400 m: 5 min a 8 m/s y 10 min a 4 m/s.
    expect(ritmo.paraRecorrer(2400), rango(5, 10));
  });

  test('los buses de la ruta suman: tres buses, dos minutos cada uno', () {
    anda('B1', 5, minutos: 2);
    anda('B2', 5, minutos: 2, desde: 1000);
    anda('B3', 5, minutos: 2, desde: 2000);

    expect(ritmo.paraRecorrer(600), rango(2, 2));
  });

  test('un bus parqueado ni suma minutos ni baja el ritmo', () {
    anda('B1', 5, minutos: 6);
    anda('PARQUEADO', 0, minutos: 10, desde: 3900);

    expect(ritmo.paraRecorrer(3000), rango(10, 10));
  });

  test('un bus parqueado no es ritmo: solo, no dice nada', () {
    anda('PARQUEADO', 0, minutos: 10, desde: 3900);

    expect(ritmo.paraRecorrer(1000), isNull);
  });

  test('un bus sin señal no cuenta', () {
    for (var s = 0; s <= 600; s += 10) {
      ritmo.ver(bus('B1', 'RECTA', 5.0 * s, 0, segundos: s, sinSenal: true));
    }

    expect(ritmo.paraRecorrer(1000), isNull);
  });

  test('un hueco sin posiciones no se promedia: corta el minuto', () {
    anda('B1', 5, minutos: 3);
    // Tres minutos callado, parado en el mismo sitio, y sigue.
    anda('B1', 5, minutos: 3, desde: 900, inicio: 360);

    expect(ritmo.paraRecorrer(3000), rango(10, 10));
  });

  test('la misma posición repetida no cuenta dos veces', () {
    anda('B1', 5, minutos: 3);
    anda('B1', 5, minutos: 3);

    expect(ritmo.paraRecorrer(3000), isNull);
  });

  test('lo de hace más de veinte minutos se olvida', () {
    anda('B1', 8, minutos: 6);
    anda('B2', 4, minutos: 6, inicio: 26 * 60);

    expect(ritmo.paraRecorrer(2400), rango(10, 10));
  });

  test('con buses de la flota de ejemplo, el rango dice que es simulado', () {
    anda('B1', 5, minutos: 3);
    anda('B2', 5, minutos: 3, desde: 1000, simulado: true);

    expect(ritmo.paraRecorrer(3000), rango(10, 10, simulado: true));
  });

  test('en la ruta circular, cruzar el cierre se cuenta de corrido', () {
    final circulo = RitmoDeRuta(SeguidorRuta(circular().medible));
    // Baja por x = 0 y cruza el cierre en (0, 0) hacia el este, a 5 m/s.
    for (var s = 0; s <= 360; s += 10) {
      final metros = 5.0 * s;
      circulo.ver(metros <= 900
          ? bus('B1', 'CIRCULAR', 0, 900 - metros, segundos: s)
          : bus('B1', 'CIRCULAR', metros - 900, 0, segundos: s));
    }

    expect(circulo.paraRecorrer(3000), rango(10, 10));
  });
}
