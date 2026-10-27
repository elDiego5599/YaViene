import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/dialogo.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/alert_toggle_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/rueda_distancia.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/alert_history_provider.dart';
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
      WidgetTester tester, List<BusPosition> buses,
      {bool omitirExplicacionSeguimiento = true}) async {
    SharedPreferences.setMockInitialValues({
      'explicacion_seguir_bus_oculta': omitirExplicacionSeguimiento,
    });
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
      alertToggleProvider.overrideWith((ref) => AlertToggleController(
            ref,
            requestPermission: () async => true,
          )),
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

  // En iPhone la distancia del aviso ocupa ese espacio: lo prueba
  // eta_sheet_distancia_test.dart.
  testWidgets('hero card: con aviso activo no repite la explicación',
      (tester) async {
    final container = await pumpHero(tester, [busAt(0.02)]);
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();

    expect(find.text('Aviso activado'), findsOneWidget);
  });

  // «Ese pop up no debe existir, solo el de que ya sigue a un bus y quiere
  // seguir otro» (dueño, 2026-10-26): la primera activación va directo a la
  // rueda, sin la ventana «Aviso cuando esté cerca».
  testWidgets('la primera activación no explica nada: abre la rueda',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final container = await pumpHero(tester, [busAt(0.02)]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Avisarme cuando esté cerca'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(Dialogo), findsNothing);
    expect(find.text('Aviso cuando esté cerca'), findsNothing);
    expect(find.byType(RuedaDistancia), findsOneWidget);
    container.dispose();
  });

  testWidgets(
      'el bloqueo del aviso no flapea: se suelta 500 m más allá de donde '
      'bloquea (700 m → 1,2 km)', (tester) async {
    // Bloquea la mínima de la rueda con su margen de 200 m y no la
    // guardada: con el bus a 800 m y el kilómetro guardado, la rueda
    // todavía ofrece 500 y 600 m (dueño, 2026-10-07).
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

    // 400 m: dentro de la mínima y su margen → bloqueado.
    controller.add([busAt(0.003593)]);
    await tester.pump();
    await tester.pump();
    expect(find.text('El bus ya está cerca'), findsOneWidget);

    // 1100 m: ya no está a menos de 700 m pero sigue a menos de 1,2 km →
    // permanece bloqueado (el cruce de umbral no debe flapear el botón).
    controller.add([busAt(0.009881)]);
    await tester.pump();
    await tester.pump();
    expect(find.text('El bus ya está cerca'), findsOneWidget);

    // El icono es el que delata el estado real del latch: mientras el
    // umbral de rearme sea 1,2 km la campana sigue apagada. Un umbral
    // torcido (p. ej. 1 km) encendería la campana aquí aunque el texto
    // de la métrica no cambie.
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byIcon(Icons.notifications_off_outlined),
      findsOneWidget,
      reason: 'a los 1100 m el botón sigue bloqueado (histéresis)',
    );
    expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);

    // 1300 m: se alejó más de 1,2 km → recién ahí se desbloquea.
    controller.add([busAt(0.011678)]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Avisarme cuando esté cerca'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget,
        reason: 'pasados los 1,2 km la campana se reactiva');
    expect(find.byIcon(Icons.notifications_off_outlined), findsNothing);
  });

  testWidgets('la hoja no repite la explicación del bus que se sigue',
      (tester) async {
    final container = await pumpHero(
      tester,
      [busAt(0.02), busAt(0.02, busId: 'B-1')],
    );
    // El botón pide permiso del sistema; el aviso existente se arma directo.
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();

    // Segundo bus seleccionado: la hoja queda limpia y la acción se mantiene.
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    container.read(selectedBusesProvider.notifier).toggleBus('B-1');
    await tester.pump();
    expect(find.text('Ya sigues el bus A-1 de la ruta Ruta 1'), findsNothing);
    expect(find.byKey(const ValueKey('nota-seguimiento-actual')), findsNothing);
    expect(find.text('Avisarme cuando esté cerca'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(container.read(activeAlertsProvider), {'A-1'});
    expect(container.read(activeAlertsProvider), isNot(contains('B-1')));
  });

  testWidgets('al seguir otro bus aparece la explicación la primera vez',
      (tester) async {
    final container = await pumpHero(
      tester,
      [busAt(0.02), busAt(0.02, busId: 'B-1')],
      omitirExplicacionSeguimiento: false,
    );
    container.read(activeAlertsProvider.notifier).activateAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    container.read(selectedBusesProvider.notifier).toggleBus('B-1');
    await tester.pump();

    await tester.tap(find.text('Avisarme cuando esté cerca'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialogo), findsOneWidget);
    expect(find.text('Ya sigues un bus'), findsOneWidget);
    expect(find.text('No volver a mostrar'), findsOneWidget);
    expect(find.text('Entendido'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialogo), findsNothing,
        reason: 'el reemplazo solo muestra una explicación');
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('cancelar o cerrar la explicación no cambia el aviso ni guarda',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final container = await pumpHero(
      tester,
      [busAt(0.02), busAt(0.02, busId: 'B-1')],
      omitirExplicacionSeguimiento: false,
    );
    container.read(activeAlertsProvider.notifier).activateAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    container.read(selectedBusesProvider.notifier).toggleBus('B-1');
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    await tester.tap(find.text('Avisarme cuando esté cerca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No volver a mostrar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('explicacion_seguir_bus_oculta'), isFalse);
    expect(container.read(activeAlertsProvider), {'A-1'});
    expect(find.byType(RuedaDistancia), findsNothing);

    await tester.tap(find.text('Avisarme cuando esté cerca'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(prefs.getBool('explicacion_seguir_bus_oculta'), isFalse);
    expect(container.read(activeAlertsProvider), {'A-1'});
    expect(find.byType(RuedaDistancia), findsNothing);
  });

  testWidgets('la explicación no vuelve a salir tras marcar la opción',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final container = await pumpHero(
      tester,
      [busAt(0.02), busAt(0.02, busId: 'B-1')],
      omitirExplicacionSeguimiento: false,
    );
    container.read(activeAlertsProvider.notifier).activateAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    container.read(selectedBusesProvider.notifier).toggleBus('B-1');
    await tester.pump();

    await tester.tap(find.text('Avisarme cuando esté cerca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No volver a mostrar'));
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    expect(find.text('Ya sigues un bus'), findsNothing);
    expect(find.text('Cancelar'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('explicacion_seguir_bus_oculta'), isTrue);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avisarme cuando esté cerca'));
    await tester.pumpAndSettle();
    expect(find.text('Ya sigues un bus'), findsNothing);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('Avisarme cerca cambia el aviso tras elegir la distancia',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final container = await pumpHero(
      tester,
      [busAt(0.02), busAt(0.02, busId: 'B-1')],
      omitirExplicacionSeguimiento: false,
    );
    container.read(activeAlertsProvider.notifier).activateAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    container.read(selectedBusesProvider.notifier).toggleBus('B-1');
    await tester.pump();

    await tester.tap(find.text('Avisarme cuando esté cerca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar'), findsOneWidget,
        reason: 'al reemplazar el aviso se puede cancelar el cambio');
    expect(container.read(activeAlertsProvider), {'A-1'},
        reason: 'conserva el aviso actual mientras se elige la distancia');

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(container.read(activeAlertsProvider), {'B-1'});
    expect(container.read(proximityAlertsProvider.notifier).radioDe('A-1'),
        isNull);
    expect(container.read(proximityAlertsProvider.notifier).radioDe('B-1'),
        isNotNull);
    expect(
      container
          .read(alertHistoryProvider)
          .where((entry) => !entry.sent)
          .map((entry) => entry.busId)
          .toSet(),
      {'B-1'},
    );
  });
}
