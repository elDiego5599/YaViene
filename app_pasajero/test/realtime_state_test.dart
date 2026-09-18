import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/domain/repositories/realtime_repository.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/realtime_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/idle_status_chip.dart';

class FakeRealtimeRepository implements RealtimeRepository {
  final _connection = StreamController<ConnectionStatus>.broadcast();
  final _busPosition = StreamController<Map<String, dynamic>>.broadcast();
  final _batch = StreamController<Map<String, dynamic>>.broadcast();
  final _left = StreamController<Map<String, dynamic>>.broadcast();
  final _hidden = StreamController<Map<String, dynamic>>.broadcast();
  final _visible = StreamController<Map<String, dynamic>>.broadcast();
  final _removed = StreamController<Map<String, dynamic>>.broadcast();
  final subscribed = <String>[];
  final unsubscribed = <String>[];

  @override
  ConnectionStatus? lastConnectionState;
  bool _isConnected = false;

  void setConnected(bool value) => _isConnected = value;

  void emitConnection(ConnectionStatus status) => _connection.add(status);
  void emitBusPosition(Map<String, dynamic> event) => _busPosition.add(event);
  void emitBatch(Map<String, dynamic> event) => _batch.add(event);
  void emitLeft(Map<String, dynamic> event) => _left.add(event);
  void emitHidden(Map<String, dynamic> event) => _hidden.add(event);
  void emitVisible(Map<String, dynamic> event) => _visible.add(event);
  void emitRemoved(Map<String, dynamic> event) => _removed.add(event);

  void closeStreams() {
    _connection.close();
    _busPosition.close();
    _batch.close();
    _left.close();
    _hidden.close();
    _visible.close();
    _removed.close();
  }

  @override
  Stream<ConnectionStatus> get connectionStateStream => _connection.stream;
  @override
  Stream<Map<String, dynamic>> get busPositionStream => _busPosition.stream;
  @override
  Stream<Map<String, dynamic>> get batchPositionStream => _batch.stream;
  @override
  Stream<Map<String, dynamic>> get busLeftStream => _left.stream;
  @override
  Stream<Map<String, dynamic>> get busHiddenStream => _hidden.stream;
  @override
  Stream<Map<String, dynamic>> get busVisibleStream => _visible.stream;
  @override
  Stream<Map<String, dynamic>> get busRemovedStream => _removed.stream;

  @override
  bool get isConnected => _isConnected;
  @override
  void connect() {}
  @override
  void subscribeToRoute(String routeId) => subscribed.add(routeId);
  @override
  void unsubscribeFromRoute(String routeId) => unsubscribed.add(routeId);
  @override
  void disconnect() {}
  @override
  void dispose() {}
}

ProviderContainer containerWith(FakeRealtimeRepository fake) {
  final container = ProviderContainer(overrides: [
    realtimeServiceProvider.overrideWithValue(fake),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

Map<String, dynamic> positionJson(
  String busId,
  double lat,
  double lon, {
  String routeId = 'R1',
  bool isGhost = false,
}) =>
    {
      'busId': busId,
      'routeId': routeId,
      'lat': lat,
      'lon': lon,
      'heading': 0,
      'speedKmh': 30,
      // Ahora: una posición en vivo con fecha de hace meses ya no se acepta
      // (`BusPosition.tryParse`), y aquí todas hacen de buses en vivo.
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'isGhost': isGhost,
    };

void main() {
  test('la conexión re-emite el último estado conocido al arrancar', () async {
    final fake = FakeRealtimeRepository()
      ..lastConnectionState = ConnectionStatus.disconnected;
    final container = containerWith(fake);

    final sub = container.listen<AsyncValue<ConnectionStatus>>(
      connectionStateProvider,
      (_, __) {},
    );
    await flush();
    expect(sub.read().value, ConnectionStatus.disconnected);

    fake.emitConnection(ConnectionStatus.connected);
    await flush();
    expect(sub.read().value, ConnectionStatus.connected);
  });

  test('la conexión sigue la secuencia y nunca se queda en loading', () async {
    final fake = FakeRealtimeRepository();
    final container = containerWith(fake);

    final sub = container.listen<AsyncValue<ConnectionStatus>>(
      connectionStateProvider,
      (_, __) {},
    );
    await flush();

    fake.emitConnection(ConnectionStatus.reconnecting);
    await flush();
    expect(sub.read().value, ConnectionStatus.reconnecting);

    fake.emitConnection(ConnectionStatus.connected);
    await flush();
    expect(sub.read().value, ConnectionStatus.connected);

    fake.emitConnection(ConnectionStatus.disconnected);
    await flush();
    expect(sub.read().value, ConnectionStatus.disconnected);

    fake.closeStreams();
    await flush();
    expect(sub.read().hasValue, true,
        reason: 'al cerrarse el stream no debe volver a loading');
    expect(sub.read().value, ConnectionStatus.disconnected);
  });

  test('el batch filtra por ruta y limpia lo que ya no está', () async {
    final fake = FakeRealtimeRepository();
    final container = containerWith(fake);
    final positions = container.listen<AsyncValue<List<BusPosition>>>(
      busPositionsSourceProvider('R1'),
      (_, __) {},
    );
    await flush();

    fake.emitBatch({
      'routeId': 'R1',
      'buses': [
        positionJson('A-1', 6.24, -75.58),
        positionJson('B-2', 6.25, -75.59),
      ],
    });
    await flush();
    expect(positions.read().value?.length, 2);

    fake.emitBatch({
      'routeId': 'R2',
      'buses': [positionJson('C-3', 6.30, -75.60, routeId: 'R2')],
    });
    await flush();
    expect(positions.read().value?.length, 2,
        reason: 'batch de otra ruta se ignora');

    fake.emitBatch({'routeId': 'R1', 'buses': <Object>[]});
    await flush();
    expect(positions.read().value?.length, 0,
        reason: 'batch vacío borra los buses que ya no están en la ruta');
  });

  test(
      'el batch no filtra su basura: los buses malformados se ignoran '
      'sin tumbar la suscripción',
      () async {
    final fake = FakeRealtimeRepository();
    final container = containerWith(fake);
    final positions = container.listen<AsyncValue<List<BusPosition>>>(
      busPositionsSourceProvider('R1'),
      (_, __) {},
    );
    await flush();

    fake.emitBatch({'routeId': 'R1', 'buses': 'esto no es una lista'});
    await flush();
    expect(positions.read().hasValue, true,
        reason:
            'batch con forma inválida debe ignorarse, no romper el provider');

    fake.emitBatch({
      'routeId': 'R1',
      'buses': [
        positionJson('A-1', 6.24, -75.58),
        {'busId': 'X-ROTO'}, // sin lat/lon
        42, // ni siquiera es un mapa
      ],
    });
    await flush();
    expect(positions.read().value?.length, 1,
        reason: 'el bus válido sobrevive y los rotos se descartan');
    expect(positions.read().value?.first.busId, 'A-1');
  });

  test(
      'ráfaga de posiciones en vivo produce una sola actualización '
      '(debounce 200ms)',
      () async {
    final fake = FakeRealtimeRepository();
    final container = containerWith(fake);
    var emissions = 0;
    final positions = container.listen<AsyncValue<List<BusPosition>>>(
      busPositionsSourceProvider('R1'),
      (_, __) => emissions++,
    );
    await flush();

    for (var i = 0; i < 10; i++) {
      fake.emitBusPosition(positionJson('A-1', 6.24 + i * 0.001, -75.58));
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(emissions, 1,
        reason: '10 eventos vivos deben colapsar en 1 snapshot');
    expect(positions.read().value?.first.lat, closeTo(6.249, 0.0001),
        reason: 'la última posición es la que queda');
  });

  test('bus:left quita el bus de la lista', () async {
    final fake = FakeRealtimeRepository();
    final container = containerWith(fake);
    final positions = container.listen<AsyncValue<List<BusPosition>>>(
      busPositionsSourceProvider('R1'),
      (_, __) {},
    );
    await flush();

    fake.emitBatch({
      'routeId': 'R1',
      'buses': [
        positionJson('A-1', 6.24, -75.58),
        positionJson('B-2', 6.25, -75.59)
      ],
    });
    await flush();
    expect(positions.read().value?.length, 2);

    fake.emitLeft({'busId': 'A-1'});
    await flush();
    expect(positions.read().value?.map((p) => p.busId).toList(), ['B-2']);
  });

  testWidgets(
      'el chip de estado sigue la conexión: desconectado, '
      'reconectando y en línea',
      (tester) async {
    final fake = FakeRealtimeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [realtimeServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(
          home: Scaffold(body: IdleStatusChip()),
        ),
      ),
    );

    fake.emitConnection(ConnectionStatus.disconnected);
    await tester.pump();
    expect(find.text('Sin conexión al servidor'), findsOneWidget);

    fake.emitConnection(ConnectionStatus.reconnecting);
    await tester.pump();
    expect(find.text('Reconectando...'), findsOneWidget);

    fake.emitConnection(ConnectionStatus.connected);
    await tester.pump();
    expect(find.text('Sin conexión al servidor'), findsNothing);
    expect(find.text('Reconectando...'), findsNothing);
  });
}
