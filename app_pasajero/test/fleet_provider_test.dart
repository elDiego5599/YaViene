import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/domain/repositories/realtime_repository.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/realtime_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';

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
  void subscribeToAllRoutes(Set<String> routeIds) =>
      subscribedRoutes.addAll(routeIds);

  @override
  void unsubscribeFromAllRoutes(Set<String> routeIds) =>
      subscribedRoutes.removeAll(routeIds);

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
      companiesProvider.overrideWith(
        (ref) async => const [Company(id: 'EMP-01', name: 'Sobusa')],
      ),
      routesByCompanyProvider.overrideWith((ref, companyId) async => const [
        RouteInfo(id: 'R-101', name: 'Tcherassi', companyId: 'EMP-01'),
        RouteInfo(id: 'R-102', name: 'Otra', companyId: 'EMP-01'),
      ]),
    ]);
    addTearDown(container.dispose);
  });

  List<BusPosition>? currentFleet(ProviderContainer c) =>
      c.read(fleetBusesProvider).value;

  test('suscribe a todas las rutas de la empresa sin empresa elegida', () async {
    container.listen(fleetBusesProvider, (_, __) {});
    await pumpEventQueue();
    expect(fake.subscribedRoutes, {'R-101', 'R-102'});
  });

  test('un batch de una ruta suscrita puebla la flota', () async {
    container.listen(fleetBusesProvider, (_, __) {});
    await pumpEventQueue();

    fake._batch.add({
      'routeId': 'R-101',
      'buses': [_busJson('BUS-SQA101', 'R-101'), _busJson('BUS-X2', 'R-101')],
    });
    await pumpEventQueue();

    final fleet = currentFleet(container);
    expect(fleet, isNotNull);
    expect(fleet!.length, 2);
    expect(fleet.map((b) => b.busId).toSet(), {'BUS-SQA101', 'BUS-X2'});
  });

  test('un batch de una ruta no suscrita se ignora', () async {
    container.listen(fleetBusesProvider, (_, __) {});
    await pumpEventQueue();

    fake._batch.add({
      'routeId': 'R-999',
      'buses': [_busJson('BUS-PIRATA', 'R-999')],
    });
    await pumpEventQueue();

    expect(currentFleet(container) ?? const [], isEmpty);
  });

  test('bus:left elimina el bus de la flota', () async {
    container.listen(fleetBusesProvider, (_, __) {});
    await pumpEventQueue();

    fake._batch.add({
      'routeId': 'R-101',
      'buses': [_busJson('BUS-SQA101', 'R-101'), _busJson('BUS-X2', 'R-101')],
    });
    fake._busLeft.add({'routeId': 'R-101', 'busId': 'BUS-SQA101'});
    await pumpEventQueue();

    final fleet = currentFleet(container);
    expect(fleet!.map((b) => b.busId).toSet(), {'BUS-X2'});
  });

  test('bus:hidden con eventId único elimina el bus', () async {
    container.listen(fleetBusesProvider, (_, __) {});
    await pumpEventQueue();

    fake._batch.add({
      'routeId': 'R-102',
      'buses': [_busJson('BUS-Y1', 'R-102')],
    });
    fake._busHidden.add({
      'routeId': 'R-102',
      'busId': 'BUS-Y1',
      'eventId': 'evt-1',
    });
    await pumpEventQueue();

    expect(currentFleet(container) ?? const [], isEmpty);
  });
}
