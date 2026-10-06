import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/geo.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/map_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rutas.json trae las rutas de Sobusa y Coolitoral con geometría',
      () async {
    final raw = await rootBundle.loadString('assets/data/rutas.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rutas = (decoded['rutas'] as List<dynamic>)
        .map((e) => RutaSobusa.fromJson(e as Map<String, dynamic>))
        .toList();

    // R-101…R-106 son de Sobusa y R-107, R-109 y R-110 de Coolitoral (A1,
    // A3 y A4), con los mismos identificadores que su catálogo en el
    // backend. A2 (R-108) se quitó (dueño, 2026-10-05): era el mismo
    // recorrido que A1; su número no se reusa.
    expect(rutas.map((r) => r.routeId), [
      'R-101', 'R-102', 'R-103', 'R-104', 'R-105', 'R-106', //
      'R-107', 'R-109', 'R-110',
    ]);

    for (final ruta in rutas) {
      expect(ruta.name, isNotEmpty, reason: '${ruta.routeId} sin nombre');
      expect(ruta.waypoints.length, greaterThanOrEqualTo(100),
          reason: '${ruta.routeId} con geometría demasiado corta');
      expect(ruta.lengthKm, greaterThan(20),
          reason: '${ruta.routeId} con longitud sospechosa');
      for (final p in ruta.waypoints) {
        expect(p.lat, inInclusiveRange(10.8, 11.2));
        expect(p.lon, inInclusiveRange(-75.0, -74.6));
      }
    }
  });

  // Las rutas de Coolitoral salen de los KMZ que mandó la empresa (dueño,
  // 2026-10-05), no de los GPX ni de las líneas de Google que se calzaban
  // sobre OSRM u OSM. Cada KMZ es un circuito cerrado que sale y vuelve al
  // mismo punto de la Calle 17 en Sur Oriente; aquí van ese punto, el más
  // lejano de cada circuito y la longitud que mide el convertidor. Si una
  // ruta vuelve a una fuente vieja, esto lo dice (A3 calzada medía 21,1 km
  // y no llegaba a Riomar por la Calle 84).
  test('Coolitoral sigue los circuitos de sus KMZ', () async {
    final raw = await rootBundle.loadString('assets/data/rutas.json');
    final rutas = ((jsonDecode(raw) as Map<String, dynamic>)['rutas']
            as List<dynamic>)
        .map((e) => RutaSobusa.fromJson(e as Map<String, dynamic>))
        .toList();
    const salida = (10.967503, -74.774768); // Cl. 17, Sur Oriente
    const circuitos = {
      'R-107': (41.6, (11.020563, -74.873080)), // A1, Sabanilla Montecarmelo
      'R-109': (23.3, (11.006723, -74.826168)), // A3, Riomar
      'R-110': (24.1, (11.004977, -74.827663)), // A4, Riomar
    };
    for (final MapEntry(key: id, value: (km, lejano)) in circuitos.entries) {
      final ruta = rutas.firstWhere((r) => r.routeId == id);
      final primero = ruta.waypoints.first;
      expect(haversineMeters(salida.$1, salida.$2, primero.lat, primero.lon),
          lessThan(1),
          reason: '$id no sale de la Calle 17');
      // Los puntos van cada 80 m como mínimo: a 100 m del punto más lejano
      // siempre queda uno si la ruta llega hasta allá.
      final cerca = ruta.waypoints
          .map((p) => haversineMeters(lejano.$1, lejano.$2, p.lat, p.lon))
          .reduce((a, b) => a < b ? a : b);
      expect(cerca, lessThan(100), reason: '$id no llega a $lejano');
      expect(ruta.lengthKm, km, reason: '$id no mide lo de su KMZ');
    }
  });

  test('el área del mapa contiene todas las rutas enteras', () async {
    // El mapa ya no deja alejarse de Barranquilla: la cámara vive dentro de
    // MapConstants.area*. Si mañana entra una ruta que sale de ese
    // rectángulo, el pasajero podría seguir un bus hasta que la cámara se
    // topara con una pared invisible. Este test lo dice antes.
    final raw = await rootBundle.loadString('assets/data/rutas.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rutas = (decoded['rutas'] as List<dynamic>)
        .map((e) => RutaSobusa.fromJson(e as Map<String, dynamic>))
        .toList();

    for (final ruta in rutas) {
      for (final p in ruta.waypoints) {
        expect(
          p.lat,
          inInclusiveRange(MapConstants.areaSurLat, MapConstants.areaNorteLat),
          reason: '${ruta.name} se sale del área por el norte o el sur',
        );
        expect(
          p.lon,
          inInclusiveRange(MapConstants.areaOesteLon, MapConstants.areaEsteLon),
          reason: '${ruta.name} se sale del área por el este o el oeste',
        );
      }
    }
  });

  test('las paradas quedan vacías (buses sin paradas fijas)', () async {
    final raw = await rootBundle.loadString('assets/data/rutas.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rutas = (decoded['rutas'] as List<dynamic>)
        .map((e) => RutaSobusa.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final ruta in rutas) {
      expect(ruta.paradas, isEmpty,
          reason: '${ruta.routeId} no debería tener paradas');
    }
  });
}
