import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/bus_hit_test.dart';

void main() {
  test('elige el bus más cercano, no el primero de MapLibre', () {
    final selected = nearestBusId(
      const Offset(200, 200),
      const [
        BusScreenPoint(busId: 'lejos', offset: Offset(220, 200)),
        BusScreenPoint(busId: 'cerca', offset: Offset(202, 201)),
      ],
    );

    expect(selected, 'cerca');
  });

  test('no selecciona un bus fuera del radio de toque', () {
    final selected = nearestBusId(
      const Offset(200, 200),
      const [
        BusScreenPoint(busId: 'bus', offset: Offset(240, 200)),
      ],
      maxDistance: 32,
    );

    expect(selected, isNull);
  });
}
