// Cómo lee el panel un bus del servidor. Lo que falta o viene vacío tiene
// que caer del lado prudente: un bus que el servidor no dice visible no se
// da por visible, y una ruta vacía es «sin ruta», no una ruta llamada «».
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';

void main() {
  test('visible solo si el servidor lo dice', () {
    expect(
      FleetBus.fromJson({'busId': 'B-1', 'visible': true}).visible,
      isTrue,
    );
    expect(FleetBus.fromJson({'busId': 'B-1'}).visible, isFalse);
    expect(
      FleetBus.fromJson({'busId': 'B-1', 'visible': 'true'}).visible,
      isFalse,
    );
  });

  test('una ruta vacía es un bus sin ruta', () {
    expect(FleetBus.fromJson({'busId': 'B-1', 'routeId': ''}).routeId, isNull);
    expect(FleetBus.fromJson({'busId': 'B-1'}).routeId, isNull);
    expect(
      FleetBus.fromJson({'busId': 'B-1', 'routeId': 'R-1'}).routeId,
      'R-1',
    );
  });

  test('lee enTerminal de contrato y distingue el default ausente', () {
    expect(
      FleetBus.fromJson({'busId': 'B-1', 'enTerminal': true}).enTerminal,
      isTrue,
    );
    expect(FleetBus.fromJson({'busId': 'B-1'}).enTerminal, isFalse);
  });
}
