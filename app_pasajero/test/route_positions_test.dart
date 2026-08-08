import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/domain/repositories/realtime_repository.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/realtime_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';

class _FakeRealtimeService implements RealtimeRepository {
  final _connectionState = StreamController<ConnectionStatus>.broadcast();
  final _busPosition = StreamController<Map<String, dynamic>>.broadcast();
  final _batch = StreamController<Map<String, dynamic>>.broadcast();
  final _busLeft = StreamController<Map<String, dynamic>>.broadcast();
  final _busHidden = StreamController<Map<String, dynamic>>.broadcast();
  final _busVisible = StreamController<Map<String, dynamic>>.broadcast();
  final _busRemoved = StreamController<Map<String, dynamic>>.broadcast();

  final subscribedRoutes = <String>{};

  @override
  Stream<ConnectionStatus> get connectionStateStream =>
      _connectionState.stream;
  @override
  Stream<Map<String, dynamic>> get busPositionStream => _busPosition.stream;
  @override
  Stream<Map<String, dynamic>> get batchPositionStream => _batch.stream;
  @override
  Stream<Map<String, dynamic>> get busLeftStream => _busLeft.stream;
  @override
  Stream<Map<String, dynamic>> get busHiddenStream => _busHidden.stream;
  @override
  Stream<Map<String, dynamic>> get busVisibleStream => _busVisible.stream;
  @override
  Stream<Map<String, dynamic>> get busRemovedStream => _busRemoved.stream;

  @override
  void connect() {}

  @override
  void subscribeToRoute(String routeId) => subscribedRoutes.add(routeId);

  @override
  void unsubscribeFromRoute(String routeId) =>
      subscribedRoutes.remove(routeId);

  @override
  void dispose() {
    _connectionState.close();
    _busPosition.close();
    _batch.close();
    _busLeft.close();
    _busHidden.close();
    _busVisible.close();
    _busRemoved.close();
  }

  @override
  bool get isConnected => true;
}

Map<String, dynamic> _busJson(
  String busId,
  String routeId, {
  double lat = 10.98,
  double lon = -74.78,
}) {
  return {
    'busId': busId,
    'routeId': routeId,
    'lat': lat,
    'lon': lon,
    'heading': 90,
    'speedKmh': 25,
    'timestamp': DateTime.now().toIso8601String(),
    'isGhost': false,
  };
}

void main() {
  late _FakeRealtimeService fake;
  late ProviderContainer container;

  setUp(() {
    fake = _FakeRealtimeService();
    container = ProviderContainer(overrides: [
      realtimeServiceProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
  });

  List<BusPosition>? currentBuses(ProviderContainer c, String routeId) =>
      c.read(busPositionsSourceProvider(routeId)).value;

  test('suscribe a la ruta al escuchar el provider', () async {
    container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
    await pumpEventQueue();
    expect(fake.subscribedRoutes, {'R-101'});
  });

  test('un batch de la ruta puebla la posición de todos sus buses', () async {
    container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
    await pumpEventQueue();

    fake._batch.add({
      'routeId': 'R-101',
      'buses': [_busJson('BUS-SQA101', 'R-101'), _busJson('BUS-X2', 'R-101')],
    });
    await pumpEventQueue();

    final buses = currentBuses(container, 'R-101');
    expect(buses, isNotNull);
    expect(buses!.length, 2);
    expect(buses.map((b) => b.busId).toSet(), {'BUS-SQA101', 'BUS-X2'});
  });

  test('un batch de otra ruta se ignora', () async {
    container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
    await pumpEventQueue();

    fake._batch.add({
      'routeId': 'R-999',
      'buses': [_busJson('BUS-PIRATA', 'R-999')],
    });
    await pumpEventQueue();

    expect(currentBuses(container, 'R-101') ?? const [], isEmpty);
  });

  test('bus:left elimina el bus de la ruta', () async {
    container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
    await pumpEventQueue();

    fake._batch.add({
      'routeId': 'R-101',
      'buses': [_busJson('BUS-SQA101', 'R-101'), _busJson('BUS-X2', 'R-101')],
    });
    fake._busLeft.add({'routeId': 'R-101', 'busId': 'BUS-SQA101'});
    await pumpEventQueue();

    final buses = currentBuses(container, 'R-101');
    expect(buses!.map((b) => b.busId).toSet(), {'BUS-X2'});
  });

  test('bus:hidden con eventId único elimina el bus', () async {
    container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
    await pumpEventQueue();

    fake._batch.add({
      'routeId': 'R-101',
      'buses': [_busJson('BUS-Y1', 'R-101')],
    });
    fake._busHidden.add({
      'routeId': 'R-101',
      'busId': 'BUS-Y1',
      'eventId': 'evt-1',
    });
    await pumpEventQueue();

    expect(currentBuses(container, 'R-101') ?? const [], isEmpty);
  });

  group('nearbyBusesCountProvider (2 km)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('sin posición del usuario → null', () async {
      container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
      await pumpEventQueue();
      expect(container.read(nearbyBusesCountProvider('R-101')), isNull);
    });

    test('cuenta solo buses a <2 km del centro', () async {
      // Usuario en (10.9800, -74.7800). Bus A en el mismo punto (0 m),
      // bus B a ~2.2 km (0.02 grados de latitud).
      container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
      await pumpEventQueue();

      fake._batch.add({
        'routeId': 'R-101',
        'buses': [
          _busJson('BUS-A', 'R-101', lat: 10.98, lon: -74.78),
          _busJson('BUS-B', 'R-101', lat: 11.0, lon: -74.78),
        ],
      });
      container
          .read(userLocationProvider.notifier)
          .setManualPin(10.98, -74.78);
      await pumpEventQueue();

      expect(container.read(nearbyBusesCountProvider('R-101')), 1);
    });

    test('con todos los buses lejos → 0', () async {
      container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
      await pumpEventQueue();

      fake._batch.add({
        'routeId': 'R-101',
        'buses': [_busJson('BUS-B', 'R-101', lat: 11.02, lon: -74.78)],
      });
      container
          .read(userLocationProvider.notifier)
          .setManualPin(10.98, -74.78);
      await pumpEventQueue();

      expect(container.read(nearbyBusesCountProvider('R-101')), 0);
    });
  });
}
