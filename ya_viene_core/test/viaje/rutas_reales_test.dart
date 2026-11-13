// El planificador contra las 15 rutas de verdad (assets/data/rutas.json) y
// sitios de verdad (assets/data/lugares_osm.json). Las pruebas dibujadas
// dicen qué debe hacer; estas fijan que en Barranquilla lo hace, y a
// tiempo.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

List<RutaDeLaRed> _rutas() {
  final json = jsonDecode(File('assets/data/rutas.json').readAsStringSync())
      as Map<String, dynamic>;
  return [
    for (final ruta in json['rutas'] as List)
      if (RutaSobusa.fromJson(ruta as Map<String, dynamic>) case final ruta)
        RutaDeLaRed(
          id: ruta.routeId,
          empresa: 'EMP',
          medible: RutaMedible.de(ruta.waypoints)!,
        ),
  ];
}

List<Lugar> _sitios() {
  final json =
      jsonDecode(File('assets/data/lugares_osm.json').readAsStringSync())
          as Map<String, dynamic>;
  return [
    for (final sitio in json['sitios'] as List)
      _sitio(
        sitio['n'] as String,
        ((sitio['p'] as List)[0] as num).toDouble(),
        ((sitio['p'] as List)[1] as num).toDouble(),
      ),
  ];
}

Lugar _sitio(String nombre, double lat, double lon) => Lugar(
      punto: GeoPoint(lat: lat, lon: lon),
      origen: OrigenLugar.sitio,
      nombre: nombre,
    );

// Coordenadas de lugares_osm.json.
final _portalDelPrado = _sitio('Portal del Prado', 10.98954, -74.78858);
final _uninorte = _sitio('Universidad del Norte', 11.02209, -74.85136);
final _catedral = _sitio('Catedral Metropolitana', 10.9885, -74.79061);
final _viva = _sitio('C. C. Viva', 11.00915, -74.82082);
final _terminal = _sitio('Terminal de Transportes', 10.90946, -74.79426);
final _zoologico = _sitio('Zoológico de Barranquilla', 11.01097, -74.798);
final _romelio = _sitio('Estadio Romelio Martínez', 10.99382, -74.80706);
final _plazaRomelio = _sitio('Plaza Romelio Martínez', 10.99478, -74.80695);
final _aeropuerto = _sitio('Aeropuerto Ernesto Cortissoz', 10.88798, -74.78178);

List<String> _rutasDe(Plan plan) => switch (plan) {
      PlanConViajes(:final viajes) => [
          for (final viaje in viajes)
            [for (final tramo in viaje.enBus) tramo.ruta].join('+'),
        ],
      _ => fail('se esperaban viajes y salió $plan'),
    };

void main() {
  late RedDeRutas red;
  late Duration armarLaRed;

  setUpAll(() {
    final reloj = Stopwatch()..start();
    red = RedDeRutas(_rutas());
    armarLaRed = reloj.elapsed;
  });

  test('la red de las 15 rutas se arma en menos de dos segundos', () {
    // En el Mac son unos 150 ms; el tope deja holgura para la CI.
    expect(red.rutas, hasLength(15));
    expect(armarLaRed, lessThan(const Duration(seconds: 2)));
  });

  group('viajes conocidos', () {
    test('del Portal del Prado a la Universidad del Norte, la C14', () {
      final plan = planear(_portalDelPrado, _uninorte, red) as PlanConViajes;
      final viaje = plan.viajes.first;

      expect(viaje.enBus.single.ruta, 'R-105');
      // 7,75 km en línea recta: la ruta los hace en unos 8.
      expect(viaje.metrosEnBus, closeTo(8100, 300));
      expect(viaje.caminataTotal, lessThan(1000));
    });

    test('de la Catedral al Viva hay tres rutas, la C13 primero', () {
      expect(_rutasDe(planear(_catedral, _viva, red)),
          ['R-104', 'R-110', 'R-105']);
    });

    test(
        'de la Terminal al Zoológico va primero la que anda 15 km, no la '
        'que anda 21 por caminar menos', () {
      final plan = planear(_terminal, _zoologico, red) as PlanConViajes;

      expect(plan.viajes.first.enBus.single.ruta, 'R-101');
      expect(plan.viajes.first.metrosEnBus, closeTo(15500, 500));
      // La A15 anda 27 km para lo mismo: no se ofrece.
      expect(_rutasDe(plan), isNot(contains('R-111')));
    });

    test('ida y vuelta no son el mismo viaje: cada sentido tiene su calle', () {
      final ida = planear(_portalDelPrado, _uninorte, red) as PlanConViajes;
      final vuelta = planear(_uninorte, _portalDelPrado, red) as PlanConViajes;
      final deIda = ida.viajes.first.enBus.single;
      final deVuelta = vuelta.viajes.first.enBus.single;

      expect(deVuelta.ruta, deIda.ruta);
      expect(deVuelta.subida.avance, isNot(closeTo(deIda.bajada.avance, 500)));
    });

    test('del estadio Romelio a su plaza se llega antes a pie', () {
      final plan = planear(_romelio, _plazaRomelio, red);
      expect(plan, isA<PlanMuyCerca>());
      expect((plan as PlanMuyCerca).metros, closeTo(107, 5));
    });

    test('al aeropuerto no llega ninguna de las 15, y lo dice', () {
      final plan = planear(_aeropuerto, _uninorte, red);
      expect(plan, isA<PlanSinRuta>());
      expect((plan as PlanSinRuta).pasaCercaDelOrigen, isFalse);
      expect(plan.pasaCercaDelDestino, isTrue);
    });
  });

  test(
      'dos mil búsquedas entre sitios de verdad: cada una en menos de 50 ms '
      'y ningún viaje rompe las reglas', () {
    final sitios = _sitios();
    final azar = math.Random(3);
    const opciones = OpcionesDePlan();
    var conViajes = 0;
    var peor = Duration.zero;

    for (var i = 0; i < 2000; i++) {
      final origen = sitios[azar.nextInt(sitios.length)];
      final destino = sitios[azar.nextInt(sitios.length)];
      final reloj = Stopwatch()..start();
      final plan = planear(origen, destino, red);
      final tardo = reloj.elapsed;
      if (tardo > peor) peor = tardo;
      if (plan is! PlanConViajes) continue;
      conViajes++;

      final recta = haversineMeters(origen.punto.lat, origen.punto.lon,
          destino.punto.lat, destino.punto.lon);
      expect(plan.viajes.length, inInclusiveRange(1, opciones.maximo));
      for (final viaje in plan.viajes) {
        expect(viaje.buses, inInclusiveRange(1, 2));
        expect(viaje.caminataTotal, lessThan(recta));
        // Nadie le da la vuelta entera a una ruta de 40 km.
        expect(viaje.metrosEnBus, lessThanOrEqualTo(3 * recta + 2000));
        for (final tramo in viaje.tramos) {
          if (tramo is TramoAPie) {
            expect(tramo.metros, lessThanOrEqualTo(opciones.caminataMaxima));
          }
        }
      }
    }

    // Los sitios cubren toda el área metropolitana y las rutas no: con
    // viaje sale cerca de la mitad.
    expect(conViajes, greaterThan(700));
    expect(peor, lessThan(const Duration(milliseconds: 50)));
  });
}
