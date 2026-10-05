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

    // R-101…R-106 son de Sobusa y R-107…R-110 de Coolitoral (A1–A4), con
    // los mismos identificadores que su catálogo en el backend.
    expect(rutas.map((r) => r.routeId), [
      'R-101', 'R-102', 'R-103', 'R-104', 'R-105', 'R-106', //
      'R-107', 'R-108', 'R-109', 'R-110',
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

  // A1 sale de los diez hitos del mapa de Google que mandó Coolitoral,
  // trazados de calle a calle (dueño, 2026-10-05). Antes era una copia de
  // A2: si vuelve a serlo, o si se pierde un hito, esto lo dice.
  test('A1 de Coolitoral pasa por los diez hitos de su mapa', () async {
    final raw = await rootBundle.loadString('assets/data/rutas.json');
    final rutas = ((jsonDecode(raw) as Map<String, dynamic>)['rutas']
            as List<dynamic>)
        .map((e) => RutaSobusa.fromJson(e as Map<String, dynamic>))
        .toList();
    final a1 = rutas.firstWhere((r) => r.routeId == 'R-107');
    final a2 = rutas.firstWhere((r) => r.routeId == 'R-108');
    const hitos = [
      (10.9672105, -74.7747157), // Calle 17, Sur Oriente
      (10.9820382, -74.7825428), // Av. 20 de Julio con 40
      (10.9875105, -74.7897863), // Calle 44b con 53
      (11.0021807, -74.8065252), // Carrera 52 con Calle 76
      (11.001555, -74.8124798), // Carrera 50 con Calle 82
      (11.0037833, -74.8245469), // Calle 90 con 46, Riomar
      (10.9837833, -74.7997904), // Calle 63 con 38, El Recreo
      (10.9918673, -74.8224802), // Carrera 42b
      (10.9849433, -74.7814267), // Calle 40 con 44
      (10.9675728, -74.7748435), // Carrera 30 con 19, Sur Oriente
    ];
    // Los puntos van cada 80 m como mínimo: a 100 m de un hito siempre
    // queda uno si la ruta pasa por ahí.
    for (final (lat, lon) in hitos) {
      final cerca = a1.waypoints
          .map((p) => haversineMeters(lat, lon, p.lat, p.lon))
          .reduce((a, b) => a < b ? a : b);
      expect(cerca, lessThan(100), reason: 'A1 no pasa por ($lat, $lon)');
    }
    expect(a1.lengthKm, closeTo(27, 1));
    expect(a1.waypoints.length, isNot(a2.waypoints.length));
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
