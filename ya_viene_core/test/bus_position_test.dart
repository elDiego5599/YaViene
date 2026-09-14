import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

void main() {
  test('BusPosition accepts canonical ghost and epoch timestamp fields', () {
    final timestamp = DateTime(2026, 8, 4, 12).millisecondsSinceEpoch;
    final position = BusPosition.fromJson({
      'busId': 'B-042',
      'routeId': 'R-101',
      'lat': 10.99,
      'lon': -74.80,
      'heading': 90,
      'speedKmh': 30,
      'timestamp': timestamp,
      'isGhost': true,
      'sequence': 7,
    });

    expect(position.isGhostBus, isTrue);
    expect(position.timestamp.millisecondsSinceEpoch, timestamp);
    expect(position.sequence, 7);
    expect(position.toJson()['isGhost'], isTrue);
  });

  test('BusPosition rechaza el JSON sin identidad o sin coordenada', () {
    const base = {
      'busId': 'B-042',
      'routeId': 'R-101',
      'lat': 10.99,
      'lon': -74.80,
    };
    for (final falta in ['busId', 'routeId', 'lat', 'lon']) {
      final json = Map<String, dynamic>.from(base)..remove(falta);
      // Rellenar con ceros ponía el bus en (0, 0), en el golfo de Guinea.
      expect(() => BusPosition.fromJson(json), throwsFormatException,
          reason: 'sin $falta debería lanzar');
    }
    expect(
      () => BusPosition.fromJson(Map.of(base)..['lat'] = 91.0),
      throwsFormatException,
    );
    expect(
      () => BusPosition.fromJson(Map.of(base)..['busId'] = '  '),
      throwsFormatException,
    );
  });
}
