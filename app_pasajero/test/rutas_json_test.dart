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

  // A1 sale de los ocho hitos del mapa de Google que mandó Coolitoral
  // (dueño, 2026-10-05): de la Calle 17 al oeste hasta Sabanilla
  // Montecarmelo, vuelta por Uninorte y la Vía 40, y regreso por el río.
  // Antes era una copia de A2 y luego un circuito de 27 km por diez hitos:
  // si vuelve a alguno de los dos, o si se pierde un hito, esto lo dice.
  test('A1 de Coolitoral pasa por los ocho hitos de su mapa', () async {
    final raw = await rootBundle.loadString('assets/data/rutas.json');
    final rutas = ((jsonDecode(raw) as Map<String, dynamic>)['rutas']
            as List<dynamic>)
        .map((e) => RutaSobusa.fromJson(e as Map<String, dynamic>))
        .toList();
    final a1 = rutas.firstWhere((r) => r.routeId == 'R-107');
    const hitos = [
      (10.9673337, -74.7746857), // Cl. 17 #29-168, Sur Oriente
      (10.9846017, -74.8090393), // Cl. 70b #382, Suroccidente
      (10.982173, -74.8186051), // Cl. 79 A #28A-51, Suroccidente
      (11.0124807, -74.8231697), // Cra. 53 #94, Riomar
      (11.020121, -74.870658), // Cra. 51B #85-74, Sabanilla Montecarmelo
      (11.0164264, -74.8133014), // Cra. 64e #86-11, Riomar
      (11.0259176, -74.8032635), // Vía 40 #84-38, Riomar
      (10.9676348, -74.7748198), // Cl. 17 #3-08, Sur Oriente
    ];
    // Los puntos van cada 80 m como mínimo: a 100 m de un hito siempre
    // queda uno si la ruta pasa por ahí.
    for (final (lat, lon) in hitos) {
      final cerca = a1.waypoints
          .map((p) => haversineMeters(lat, lon, p.lat, p.lon))
          .reduce((a, b) => a < b ? a : b);
      expect(cerca, lessThan(100), reason: 'A1 no pasa por ($lat, $lon)');
    }
    // Google lo mide en 40,5 km; OSRM, con las mismas calles, en 41.
    expect(a1.lengthKm, closeTo(41, 1));
  });

  // A3 sale de los diez hitos del mapa de Google que mandó Coolitoral
  // (dueño, 2026-10-05): de la Calle 17 en Sur Oriente sube por la
  // Carrera 43 hasta Ciudad Jardín y Riomar, vuelve por la Calle 75, El
  // Prado y la Carrera 44, y baja por el oriente hasta Coolitoral.
  test('A3 de Coolitoral pasa por los diez hitos de su mapa', () async {
    final raw = await rootBundle.loadString('assets/data/rutas.json');
    final rutas = ((jsonDecode(raw) as Map<String, dynamic>)['rutas']
            as List<dynamic>)
        .map((e) => RutaSobusa.fromJson(e as Map<String, dynamic>))
        .toList();
    final a3 = rutas.firstWhere((r) => r.routeId == 'R-109');
    const hitos = [
      (10.9672105, -74.7747157), // Surtidos Wendy, Cl. 17, Sur Oriente
      (10.9773983, -74.7799175), // Cra. 38 #35-2, Bolívar
      (10.9814107, -74.7789747), // 20 de julio, Cra. 43 #35
      (10.9937482, -74.8135399), // Cra. 42F #75B-214
      (10.9910299, -74.8268945), // Marhemar SAS, Cl. 84 #42-13
      (11.00593, -74.8245163), // Aparta estudio Riomar
      (11.0011993, -74.8052323), // Cl. 75 #52-55
      (10.986318, -74.791986), // Estación Gazel, Kr 44 Cl 54
      (10.9849433, -74.7814267), // Porvenir, Cl. 40 #44-129
      (10.9705778, -74.7742905), // Coolitoral, Cl. 17 #24
    ];
    for (final (lat, lon) in hitos) {
      final cerca = a3.waypoints
          .map((p) => haversineMeters(lat, lon, p.lat, p.lon))
          .reduce((a, b) => a < b ? a : b);
      expect(cerca, lessThan(100), reason: 'A3 no pasa por ($lat, $lon)');
    }
    // Google lo mide en 21,8 km; calzado sobre las calles, 21,1.
    expect(a3.lengthKm, closeTo(21.5, 1));
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
