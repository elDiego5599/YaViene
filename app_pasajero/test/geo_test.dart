import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/geo.dart';

void main() {
  group('haversineMeters', () {
    test('distancia entre el mismo punto es 0', () {
      expect(haversineMeters(10.98, -74.78, 10.98, -74.78), 0);
    });

    test('~1 grado de latitud ≈ 111 km', () {
      final distance = haversineMeters(10.98, -74.78, 11.98, -74.78);
      expect(distance, closeTo(111190, 500));
    });

    test('distancias cortas (una cuadra ≈ 100 m)', () {
      final distance = haversineMeters(10.98, -74.78, 10.981, -74.78);
      expect(distance, closeTo(111, 20));
    });

    test('Barranquilla centro ↔ Aeropuerto ≈ 10 km', () {
      final distance = haversineMeters(10.9841, -74.7891, 10.8936, -74.7816);
      expect(distance, closeTo(10200, 800));
    });
  });
}
