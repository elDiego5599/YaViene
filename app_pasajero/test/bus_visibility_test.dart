import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/visible_buses_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/bus_visibility.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

const _userLat = 6.2442;
const _userLon = -75.5812;

/// Un grado de latitud son ~111,2 km con el radio que usa haversineMeters.
const _metersPerDegree = 111194.9;

BusPosition _busAtKm(double km, {String busId = 'A-1'}) => BusPosition(
      busId: busId,
      routeId: 'R1',
      lat: _userLat + (km * 1000) / _metersPerDegree,
      lon: _userLon,
      heading: 0,
      speedKmh: 30,
      timestamp: DateTime.now(),
      isGhostBus: false,
    );

void main() {
  group('filterBusesByRadius', () {
    test('sin ubicación no recorta nada: un mapa vacío sería peor', () {
      final buses = [_busAtKm(0.5), _busAtKm(40, busId: 'B-2')];

      final result = filterBusesByRadius(
        positions: buses,
        userLat: null,
        userLon: null,
        alwaysVisible: const {},
        previouslyWithinRadius: const {},
      );

      expect(result.buses, buses);
      expect(result.withinRadius, isEmpty);
    });

    test('deja los de menos de 5 km y quita los de más', () {
      final result = filterBusesByRadius(
        positions: [_busAtKm(4), _busAtKm(6, busId: 'B-2')],
        userLat: _userLat,
        userLon: _userLon,
        alwaysVisible: const {},
        previouslyWithinRadius: const {},
      );

      expect(result.buses.map((b) => b.busId), ['A-1']);
      expect(result.withinRadius, {'A-1'});
    });

    test('el que ya estaba dentro aguanta hasta 5,5 km (histéresis)', () {
      final result = filterBusesByRadius(
        positions: [_busAtKm(5.2)],
        userLat: _userLat,
        userLon: _userLon,
        alwaysVisible: const {},
        previouslyWithinRadius: const {'A-1'},
      );

      expect(result.buses.map((b) => b.busId), ['A-1']);
    });

    test('pasados los 5,5 km sale aunque estuviera dentro', () {
      final result = filterBusesByRadius(
        positions: [_busAtKm(5.8)],
        userLat: _userLat,
        userLon: _userLon,
        alwaysVisible: const {},
        previouslyWithinRadius: const {'A-1'},
      );

      expect(result.buses, isEmpty);
      expect(result.withinRadius, isEmpty);
    });

    test('el bus seleccionado o con aviso se pinta esté donde esté', () {
      final result = filterBusesByRadius(
        positions: [_busAtKm(30)],
        userLat: _userLat,
        userLon: _userLon,
        alwaysVisible: const {'A-1'},
        previouslyWithinRadius: const {},
      );

      expect(result.buses.map((b) => b.busId), ['A-1']);
      // Se pinta, pero no cuenta como "dentro": al deseleccionarlo desaparece
      // sin arrastrar el margen de salida.
      expect(result.withinRadius, isEmpty);
    });
  });

  group('visibleBusesProvider', () {
    late StreamController<List<BusPosition>> positions;

    ProviderContainer containerWithLocation({bool located = true}) {
      final container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _TestUserLocation()),
        busPositionsSourceProvider
            .overrideWith((ref, routeId) => positions.stream),
      ]);
      addTearDown(container.dispose);
      if (located) {
        (container.read(userLocationProvider.notifier) as _TestUserLocation)
            .set(const UserLocationState(
          mode: UserLocationMode.manual,
          lat: _userLat,
          lon: _userLon,
        ));
      }
      return container;
    }

    setUp(() {
      positions = StreamController<List<BusPosition>>.broadcast();
    });

    tearDown(() => positions.close());

    Future<void> emit(List<BusPosition> batch) async {
      positions.add(batch);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    List<String> visibleIds(ProviderContainer c) =>
        (c.read(visibleBusesProvider('R1')).value ?? const [])
            .map((b) => b.busId)
            .toList();

    test('la histéresis sobrevive entre lotes de posiciones', () async {
      final container = containerWithLocation();
      final sub = container.listen(visibleBusesProvider('R1'), (_, __) {});
      addTearDown(sub.close);

      await emit([_busAtKm(4)]);
      expect(visibleIds(container), ['A-1'], reason: 'entra dentro de 5 km');

      // Entre 5 y 5,5 km: ya estaba dentro, así que se queda. Esto solo pasa
      // si el notifier recuerda el lote anterior.
      await emit([_busAtKm(5.2)]);
      expect(visibleIds(container), ['A-1']);

      await emit([_busAtKm(5.8)]);
      expect(visibleIds(container), isEmpty,
          reason: 'pasó el margen de salida');

      // Y no vuelve hasta cruzar los 5 km otra vez, no los 5,5.
      await emit([_busAtKm(5.2)]);
      expect(visibleIds(container), isEmpty);
      await emit([_busAtKm(4.9)]);
      expect(visibleIds(container), ['A-1']);
    });

    test('un bus lejano con aviso armado sigue en el mapa', () async {
      final container = containerWithLocation();
      final sub = container.listen(visibleBusesProvider('R1'), (_, __) {});
      addTearDown(sub.close);

      await emit([_busAtKm(20)]);
      expect(visibleIds(container), isEmpty);

      container.read(activeAlertsProvider.notifier).activateAlert('A-1');
      await Future<void>.delayed(Duration.zero);
      expect(visibleIds(container), ['A-1'],
          reason: 'el bus del aviso no puede desaparecer mientras se espera');

      container.read(activeAlertsProvider.notifier).deactivateAlert('A-1');
      await Future<void>.delayed(Duration.zero);
      expect(visibleIds(container), isEmpty);
    });

    test('el bus seleccionado no se esfuma al alejarse del radio', () async {
      final container = containerWithLocation();
      final sub = container.listen(visibleBusesProvider('R1'), (_, __) {});
      addTearDown(sub.close);

      await emit([_busAtKm(4)]);
      container.read(selectedBusesProvider.notifier).toggleBus('A-1');
      await emit([_busAtKm(30)]);

      expect(visibleIds(container), ['A-1']);
    });

    test('sin ubicación se ven todos; al fijar el pin se recorta', () async {
      final container = containerWithLocation(located: false);
      final sub = container.listen(visibleBusesProvider('R1'), (_, __) {});
      addTearDown(sub.close);

      await emit([_busAtKm(1), _busAtKm(30, busId: 'B-2')]);
      expect(visibleIds(container), ['A-1', 'B-2']);

      (container.read(userLocationProvider.notifier) as _TestUserLocation)
          .set(const UserLocationState(
        mode: UserLocationMode.manual,
        lat: _userLat,
        lon: _userLon,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(visibleIds(container), ['A-1'],
          reason: 'mover el pin repinta sin esperar al próximo paquete');
    });

    test('busesOutOfRangeCountProvider cuenta los que quedaron fuera',
        () async {
      final container = containerWithLocation();
      final sub = container.listen(visibleBusesProvider('R1'), (_, __) {});
      addTearDown(sub.close);

      await emit([
        _busAtKm(1),
        _busAtKm(30, busId: 'B-2'),
        _busAtKm(40, busId: 'B-3'),
      ]);

      expect(container.read(busesOutOfRangeCountProvider('R1')), 2);
    });
  });
}
