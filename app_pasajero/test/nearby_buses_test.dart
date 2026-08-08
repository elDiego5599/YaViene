import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';

void main() {
  BusPosition bus(String id, double lat, double lon) => BusPosition(
        busId: id,
        routeId: 'R-101',
        lat: lat,
        lon: lon,
        heading: 0,
        speedKmh: 20,
        timestamp: DateTime.now(),
        isGhostBus: false,
      );

  // Usuario parado en el centro de Barranquilla (Plaza de la Paz).
  const userLat = 10.9841;
  const userLon = -74.7891;

  group('filterBusesByProximity', () {
    test('sin posición del usuario → toda la flota, sin filtrar', () {
      final result = filterBusesByProximity(
        [bus('B1', 11.4, -74.6), bus('B2', 10.9, -74.7)],
        null,
        null,
      );
      expect(result.filtered, isFalse);
      expect(result.nearby.length, 2);
      expect(result.far, isEmpty);
    });

    test('bus a ~800 m entra en el radio de 3 km', () {
      final result = filterBusesByProximity(
        [bus('B1', userLat + 0.0072, userLon)],
        userLat,
        userLon,
      );
      expect(result.filtered, isTrue);
      expect(result.nearby.map((b) => b.busId), contains('B1'));
    });

    test('bus a ~5 km queda en `far`', () {
      final result = filterBusesByProximity(
        [bus('B1', userLat + 0.045, userLon)],
        userLat,
        userLon,
      );
      expect(result.filtered, isTrue);
      expect(result.far.map((b) => b.busId), contains('B1'));
      expect(result.nearby, isEmpty);
    });

    test('mezcla: cerca y lejos se separan', () {
      final result = filterBusesByProximity(
        [
          bus('Cerca1', userLat + 0.005, userLon),
          bus('Lejos1', userLat + 0.09, userLon),
          bus('Cerca2', userLat - 0.008, userLon + 0.003),
        ],
        userLat,
        userLon,
      );
      expect(result.nearby.map((b) => b.busId).toSet(),
          {'Cerca1', 'Cerca2'});
      expect(result.far.map((b) => b.busId), contains('Lejos1'));
      expect(result.total, 3);
    });
  });
}
