import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/core/lugares/buscador_local.dart';
import 'package:ya_viene_core/core/lugares/lugar.dart';
import 'package:ya_viene_core/core/models/route_trajectory.dart';

/// El índice que va en la app, no el de prueba: lo que el pasajero escribe
/// tiene que encontrar lo de verdad y responder antes de la próxima tecla.
void main() {
  final buscador = BuscadorLocal.desdeJson([
    File('assets/data/lugares_osm.json').readAsStringSync(),
    File('assets/data/lugares_pot.json').readAsStringSync(),
  ]);
  const centro = GeoPoint(lat: 10.98, lon: -74.80);

  test('encuentra barrios, vías y esquinas de Barranquilla', () async {
    final prado = await buscador.buscar('el prado', sesgo: centro);
    expect(prado.first.tipo, TipoLugar.barrio);
    expect(prado.first.nombre, 'El Prado');

    // OSM llama «Avenida Olaya Herrera» a casi toda la Carrera 46, así que
    // la esquina de prueba es una que el índice de verdad sí trae.
    final esquina = await buscador.buscar('calle 30 con 38', sesgo: centro);
    expect(esquina.first.tipo, TipoLugar.cruce);
    expect(esquina.first.nombre, 'Clle 30 con Cra 38');
  });

  test('dice las dos fuentes con su licencia', () {
    expect(buscador.atribucion, contains('ODbL'));
    expect(buscador.atribucion, contains('CC BY-SA 4.0'));
  });

  test('cada consulta tarda menos de 50 ms (p95)', () async {
    const consultas = [
      'p',
      'pr',
      'pra',
      'prad',
      'prado',
      'el prado',
      'calle 72',
      'cra 46',
      'cl 72 con 46',
      'calle 72 # 46-20',
      'uninorte',
      'santa monica',
      'barrio abajo',
      'soledad',
      'portal',
      'boston',
      'la campina',
      'via 40',
      'murillo',
      'circunvalar',
    ];
    for (final q in consultas) {
      await buscador.buscar(q, sesgo: centro); // calienta el JIT
    }
    final tiempos = <int>[];
    for (var vuelta = 0; vuelta < 5; vuelta++) {
      for (final q in consultas) {
        final reloj = Stopwatch()..start();
        await buscador.buscar(q, sesgo: centro);
        tiempos.add(reloj.elapsedMicroseconds);
      }
    }
    tiempos.sort();
    final p95 = tiempos[(tiempos.length * 0.95).floor() - 1];
    expect(p95, lessThan(50000), reason: 'p95 = ${p95 / 1000} ms');
  });
}
