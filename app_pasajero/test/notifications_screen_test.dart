import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/alert_history_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

void main() {
  const userLat = 6.2442;
  const userLon = -75.5812;

  BusPosition bus(String id) => BusPosition(
        busId: id,
        routeId: 'R1',
        lat: userLat,
        lon: userLon,
        heading: 0,
        speedKmh: 30,
        timestamp: DateTime.now(),
        isGhostBus: false,
      );

  RouteInfo routeR1() => const RouteInfo(
        id: 'R1',
        name: 'Ruta 1',
        companyId: 'C1',
      );

  Future<ProviderContainer> pumpScreen(
      WidgetTester tester, List<BusPosition> buses) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(buses),
      ),
    ]);
    addTearDown(container.dispose);
    // Mantiene vivo el provider autoDispose de la ruta seleccionada: sin
    // listeners, `select` deja un Timer(0) de descarte pendiente que el
    // framework de tests reporta como "timer still pending".
    final sub = container.listen<RouteInfo?>(
      selectedRouteProvider,
      (_, __) {},
    );
    addTearDown(sub.close);
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: userLat,
        lon: userLon,
      ),
    );
    container.read(selectedRouteProvider.notifier).select(routeR1());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    return container;
  }

  void arm(ProviderContainer c, String busId) {
    c.read(activeAlertsProvider.notifier).toggleAlert(busId);
    c.read(proximityAlertsProvider.notifier).armAlert(busId, 'R1');
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('estado vacío sin avisos ni historial', (tester) async {
    await pumpScreen(tester, const []);

    expect(find.text('No tienes avisos activos'), findsOneWidget);
  });

  testWidgets('desactivar un aviso activo lo borra de la lista',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    await tester.pump();

    expect(find.text('Ruta 1 · A-1'), findsOneWidget);
    expect(find.textContaining('esperando aviso'), findsOneWidget);

    await tester.tap(find.text('Desactivar'));
    await tester.pump();

    expect(find.text('Ruta 1 · A-1'), findsNothing);
    expect(container.read(activeAlertsProvider), isEmpty);
    expect(container.read(alertHistoryProvider), isEmpty);
  });

  testWidgets('un aviso enviado se muestra como historial con su fecha',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1')]);
    arm(container, 'A-1');
    // testWidgets usa timers falsos: pump() descarga el microtask del stream.
    await tester.pump();
    await container.read(proximityAlertsProvider.notifier).check();
    await tester.pump();

    expect(find.text('Ruta 1 · A-1'), findsOneWidget);
    expect(find.text('Enviado'), findsOneWidget);
    expect(find.textContaining('Notificación enviada'), findsOneWidget);
    expect(find.text('Desactivar'), findsNothing);
  });

  testWidgets('borrar avisos seleccionados desactiva los activos',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1'), bus('A-2')]);
    arm(container, 'A-1');
    arm(container, 'A-2');
    await tester.pump();

    await tester.tap(find.text('Seleccionar'));
    await tester.pump();
    // Deja terminar la entrada de la barra inferior (AnimatedSize).
    await tester.pump(const Duration(milliseconds: 300));
    // Selecciona solo A-1 (el checkbox de su fila).
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Borrar 1'));
    await tester.pump();

    expect(find.text('Ruta 1 · A-1'), findsNothing);
    expect(find.text('Ruta 1 · A-2'), findsOneWidget);
    expect(container.read(activeAlertsProvider), {'A-2'});
  });

  testWidgets('borrar todas limpia historial y desactiva todo',
      (tester) async {
    final container = await pumpScreen(tester, [bus('A-1'), bus('A-2')]);
    arm(container, 'A-1');
    arm(container, 'A-2');
    await tester.pump();

    await tester.tap(find.text('Seleccionar'));
    await tester.pump();
    // Deja terminar la entrada de la barra inferior (AnimatedSize).
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Borrar todas'));
    await tester.pump();

    expect(find.text('No tienes avisos activos'), findsOneWidget);
    expect(container.read(activeAlertsProvider), isEmpty);
    expect(container.read(alertHistoryProvider), isEmpty);
  });
}