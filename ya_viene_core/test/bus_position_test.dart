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
}
