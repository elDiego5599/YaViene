import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
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
