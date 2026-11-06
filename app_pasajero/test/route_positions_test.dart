import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  Stream<ConnectionStatus> get connectionStateStream => _connectionState.stream;
  @override
  ConnectionStatus? get lastConnectionState => null;
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
  void reconectarYa() {}

  @override
  void subscribeToRoute(String routeId) => subscribedRoutes.add(routeId);

  @override
  void unsubscribeFromRoute(String routeId) => subscribedRoutes.remove(routeId);

  @override
  void disconnect() {}

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

/// Lo que manda el backend por bus (`toPublicPosition`), con la captura del
/// equipo en milisegundos: es lo que ordena las posiciones de un bus.
Map<String, dynamic> _busJson(
  String busId,
  String routeId, {
  double lat = 10.98,
  double lon = -74.78,
  int sequence = 1,
  int? capturedAt,
  bool isGhost = false,
}) {
  final ahora = DateTime.now();
  return {
    'busId': busId,
    'routeId': routeId,
    'lat': lat,
    'lon': lon,
    'heading': 90,
    'speedKmh': 25,
    'timestamp': ahora.toIso8601String(),
    'capturedAt': capturedAt ?? ahora.millisecondsSinceEpoch,
    'sequence': sequence,
    'isGhost': isGhost,
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

  // Los eventos llegan sin tipar. Un campo con otro tipo lanzaba dentro del
  // `listen`, y un error sin recoger ahí tumba el test.
  test('eventos con campos de otro tipo se descartan sin lanzar', () async {
    container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
    await pumpEventQueue();

    fake._batch.add({
      'routeId': 'R-101',
      'buses': [_busJson('BUS-A1', 'R-101')],
    });
    await pumpEventQueue();

    fake._batch.add({'routeId': 123, 'buses': const []});
    fake._busLeft.add({'routeId': 'R-101', 'busId': 5});
    fake._busRemoved.add({
      'routeId': 'R-101',
      'busId': ['BUS-A1'],
    });
    fake._busVisible.add({'routeId': 'R-101', 'busId': 7, 'eventId': 'e-1'});
    await pumpEventQueue();

    final buses = currentBuses(container, 'R-101');
    expect(buses!.map((b) => b.busId), ['BUS-A1']);
  });

  test('bus:visible con la posición de otro bus o de otra ruta se ignora',
      () async {
    container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
    await pumpEventQueue();

    fake._batch.add({'routeId': 'R-101', 'buses': const []});
    fake._busVisible.add({
      'routeId': 'R-101',
      'busId': 'BUS-A1',
      'eventId': 'e-1',
      'position': _busJson('BUS-OTRO', 'R-101'),
    });
    fake._busVisible.add({
      'routeId': 'R-101',
      'busId': 'BUS-A2',
      'eventId': 'e-2',
      'position': _busJson('BUS-A2', 'R-999'),
    });
    await pumpEventQueue();

    expect(currentBuses(container, 'R-101') ?? const [], isEmpty);
  });

  // Los mensajes no llegan en orden: el socket reconecta, el lote de la
  // suscripción sale de la base, el respaldo va atrás. La captura del equipo
  // es lo que decide cuál es la posición de un bus (T2.5).
  group('ninguna posición más vieja retrocede un bus', () {
    // Las posiciones en vivo salen agrupadas cada 200 ms. Con la máquina
    // cargada (la suite entera, un build al lado) el lote sale tarde y una
    // espera fija de 250 ms leía el estado antes del primer lote: se espera
    // a que el provider publique algo nuevo, hasta 5 s, y luego un lote
    // más, por si lo enviado quedó repartido en dos.
    Future<void> esperarVivo() async {
      final antes = container.read(busPositionsSourceProvider('R-101'));
      final limite = DateTime.now().add(const Duration(seconds: 5));
      while (identical(
              container.read(busPositionsSourceProvider('R-101')), antes) &&
          DateTime.now().isBefore(limite)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    late int t0;
    setUp(() => t0 = DateTime.now().millisecondsSinceEpoch);

    BusPosition unico() => currentBuses(container, 'R-101')!.single;

    test('una posición vieja que llega tarde no pisa la nueva', () async {
      container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
      await pumpEventQueue();

      fake._busPosition
        ..add(_busJson('BUS-A', 'R-101',
            lat: 10.99, sequence: 2, capturedAt: t0 + 2000))
        ..add(_busJson('BUS-A', 'R-101',
            lat: 10.98, sequence: 1, capturedAt: t0 + 1000));
      await esperarVivo();

      expect(unico().lat, 10.99);
      expect(unico().sequence, 2);
    });

    // Riesgo: el socket comparte canal entre rutas; una posición en vivo
    // de otra ruta pintaba en el mapa un bus que no pasa por aquí.
    test('una posición en vivo de otra ruta no entra', () async {
      container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
      await pumpEventQueue();

      fake._busPosition
        ..add(_busJson('BUS-PIRATA', 'R-999', capturedAt: t0 + 1000))
        ..add(_busJson('BUS-A', 'R-101', capturedAt: t0 + 1000));
      await esperarVivo();

      expect(unico().busId, 'BUS-A');
    });

    test('el fantasma con la misma captura sí cambia el estado', () async {
      container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
      await pumpEventQueue();

      fake._busPosition.add(_busJson('BUS-A', 'R-101', capturedAt: t0));
      await esperarVivo();
      fake._busPosition
          .add(_busJson('BUS-A', 'R-101', capturedAt: t0, isGhost: true));
      await esperarVivo();

      expect(unico().isGhostBus, isTrue);
    });

    test('un batch posterior a un evento vivo no lo retrocede', () async {
      container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
      await pumpEventQueue();

      fake._busPosition.add(_busJson('BUS-A', 'R-101',
          lat: 10.99, sequence: 5, capturedAt: t0 + 5000));
      await esperarVivo();
      fake._batch.add({
        'routeId': 'R-101',
        'buses': [
          _busJson('BUS-A', 'R-101',
              lat: 10.98, sequence: 3, capturedAt: t0 + 3000),
          _busJson('BUS-B', 'R-101'),
        ],
      });
      await pumpEventQueue();

      final buses = {
        for (final b in currentBuses(container, 'R-101')!) b.busId: b,
      };
      expect(buses.keys.toSet(), {'BUS-A', 'BUS-B'});
      expect(buses['BUS-A']!.lat, 10.99);
      expect(buses['BUS-A']!.sequence, 5);
    });

    test('bus:visible con una posición más vieja no lo retrocede', () async {
      container.listen(busPositionsSourceProvider('R-101'), (_, __) {});
      await pumpEventQueue();

      fake._busPosition.add(_busJson('BUS-A', 'R-101',
          lat: 10.99, sequence: 5, capturedAt: t0 + 5000));
      await esperarVivo();
      fake._busVisible.add({
        'routeId': 'R-101',
        'busId': 'BUS-A',
        'eventId': 'e-9',
        'position': _busJson('BUS-A', 'R-101',
            lat: 10.98, sequence: 3, capturedAt: t0 + 3000),
      });
      await pumpEventQueue();

      expect(unico().lat, 10.99);
    });
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
      container.read(userLocationProvider.notifier).setManualPin(10.98, -74.78);
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
      container.read(userLocationProvider.notifier).setManualPin(10.98, -74.78);
      await pumpEventQueue();

      expect(container.read(nearbyBusesCountProvider('R-101')), 0);
    });
  });
}
