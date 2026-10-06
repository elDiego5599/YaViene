import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

void main() {
  SharedPreferences.setMockInitialValues({});
  const userLat = 6.2442;
  const userLon = -75.5812;

  RouteInfo routeR1() => const RouteInfo(
        id: 'R1',
        name: 'Ruta 1',
        companyId: 'C1',
      );

  BusPosition busAt(double latOffset, {String busId = 'A-1'}) => BusPosition(
        busId: busId,
        routeId: 'R1',
        lat: userLat + latOffset,
        lon: userLon,
        heading: 0,
        speedKmh: 30,
        timestamp: DateTime.now(),
        isGhostBus: false,
      );

  Future<ProviderContainer> pumpHero(
      WidgetTester tester, List<BusPosition> buses) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(buses),
      ),
      // El recorrido pasa justo por el punto del usuario: lo que se prueba
      // aquí es el botón, no la regla de "esta ruta no pasa cerca de ti".
      routeTrajectoryProvider.overrideWith(
        (ref, routeId) => RouteTrajectory(
          routeId: routeId,
          routeName: 'Ruta 1',
          points: const [
            GeoPoint(lat: userLat, lon: userLon - 0.05),
            GeoPoint(lat: userLat, lon: userLon + 0.05),
          ],
        ),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: EtaBottomSheet()),
        ),
      ),
    );
    await tester.pump();
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: userLat,
        lon: userLon,
      ),
    );
    container.read(selectedRouteProvider.notifier).select(routeR1());
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('hero card: métrica grande en metros (850 m de ti)',
      (tester) async {
    await pumpHero(tester, [busAt(0.007645)]);

    // Encima de la distancia, «BUS» y la placa: la ruta ya está elegida.
    expect(find.text('BUS'), findsOneWidget);
    expect(find.text('A-1'), findsOneWidget);
    expect(find.text('Ruta 1 - A-1'), findsNothing);
    expect(find.text('850'), findsOneWidget,
        reason: 'el número es la métrica principal del hero');
    expect(find.text('m de ti'), findsOneWidget);
  });

  testWidgets(
      'con el aviso armado en otro pin, la distancia dice que es del pin '
      'anterior', (tester) async {
    final container = await pumpHero(tester, [busAt(0.007645)]);
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();

    // Mismo pin con el que se armó: la distancia es la de siempre.
    expect(find.text('m de ti'), findsOneWidget);

    // Pin nuevo, más al norte. El aviso sigue midiendo desde el de antes, y
    // la hoja con él: el número no cambia, pero ya no puede decir "de ti".
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: userLat + 0.01,
        lon: userLon,
      ),
    );
    await tester.pump();

    expect(find.text('850'), findsOneWidget);
    expect(find.text('m de tu pin anterior'), findsOneWidget);
    expect(find.text('m de ti'), findsNothing);
  });

  testWidgets('hero card: métrica en kilómetros (2,2 km de ti)',
      (tester) async {
    await pumpHero(tester, [busAt(0.02)]);

    expect(find.text('2,2'), findsOneWidget);
    expect(find.text('km de ti'), findsOneWidget);
  });

  testWidgets('hero card: bus a menos de 1 km muestra "ya está cerca"',
      (tester) async {
    await pumpHero(tester, [busAt(0.002)]);

    expect(find.text('222'), findsOneWidget);
    expect(find.text('m de ti'), findsOneWidget);
    expect(find.text('El bus ya está cerca'), findsOneWidget);
    expect(find.text('Va pasando'), findsNothing);
  });

  testWidgets('hero card: sin ubicación muestra estado y no métrica',
      (tester) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([busAt(0.007645)]),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: EtaBottomSheet()),
        ),
      ),
    );
    await tester.pump();
    container.read(selectedRouteProvider.notifier).select(routeR1());
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pump();
    // Deja terminar el fundido del AnimatedSwitcher de la hoja
    // (`AppMotion.pausado`).
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Sin tu ubicación'), findsOneWidget);
    expect(find.text('Toca el mapa para indicar dónde estás'), findsOneWidget);
  });

  // En iPhone esa nota la toma la distancia del aviso: lo prueba
  // eta_sheet_distancia_test.dart.
  testWidgets('hero card: con aviso activo, la nota dice cómo cuidarlo',
      (tester) async {
    final container = await pumpHero(tester, [busAt(0.02)]);
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();

    expect(find.text('Aviso activado'), findsOneWidget);
    expect(
        find.text('Puedes cambiar de aplicación; no cierres Ya Viene del todo'),
        findsOneWidget);
  });

  testWidgets(
      'el bloqueo del aviso no flapea: se suelta 500 m más allá de la '
      'distancia guardada (1 km → 1500 m)', (tester) async {
    // La distancia del aviso la guarda la persona; aquí, el kilómetro.
    SharedPreferences.setMockInitialValues({'distancia_aviso_m': 1000});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final controller = StreamController<List<BusPosition>>();
    addTearDown(controller.close);
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => controller.stream,
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: EtaBottomSheet()),
        ),
      ),
    );
    await tester.pump();
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: userLat,
        lon: userLon,
      ),
    );
    container.read(selectedRouteProvider.notifier).select(routeR1());
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pump();

    // 800 m: dentro del radio de aviso → bloqueado.
    controller.add([busAt(0.007186)]);
    await tester.pump();
    await tester.pump();
    expect(find.text('El bus ya está cerca'), findsOneWidget);

    // 1100 m: ya no está dentro del radio pero sigue a menos de 1500 m →
    // permanece bloqueado (el cruce de umbral no debe flapear el botón).
    controller.add([busAt(0.009881)]);
    await tester.pump();
    await tester.pump();
    expect(find.text('El bus ya está cerca'), findsOneWidget);

    // El icono es el que delata el estado real del latch: mientras el
    // umbral de rearme sea 1500 m la campana sigue apagada. Un umbral
    // torcido (p. ej. 500 m) encendería la campana aquí aunque el texto
    // de la métrica no cambie.
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byIcon(Icons.notifications_off_outlined),
      findsOneWidget,
      reason: 'a los 1100 m el botón sigue bloqueado (histéresis)',
    );
    expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);

    // 1600 m: se alejó más de 1500 m → recién ahí se desbloquea.
    controller.add([busAt(0.014373)]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Avisarme cuando esté cerca'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget,
        reason: 'pasados los 1500 m la campana se reactiva');
    expect(find.byIcon(Icons.notifications_off_outlined), findsNothing);
  });

  testWidgets('máximo 2 avisos activos: el tercero muestra el mensaje',
      (tester) async {
    final container = await pumpHero(
      tester,
      [busAt(0.02), busAt(0.02, busId: 'B-1'), busAt(0.02, busId: 'C-1')],
    );
    // Dos avisos ya armados (el botón pide permiso de notificaciones, que no
    // se puede conceder en test: se arman directo por los notifiers).
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    container.read(activeAlertsProvider.notifier).toggleAlert('B-1');
    container.read(proximityAlertsProvider.notifier).armAlert('B-1', 'R1');
    await tester.pump();

    // Tercer bus seleccionado: el botón debe explicar el límite, no armar.
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    container.read(selectedBusesProvider.notifier).toggleBus('C-1');
    await tester.pump();
    await tester.tap(find.text('Avisarme cuando esté cerca'));
    await tester.pump();

    expect(find.textContaining('Ya tienes 2 avisos activos'), findsOneWidget);
    expect(container.read(activeAlertsProvider), isNot(contains('C-1')));
  });
}
