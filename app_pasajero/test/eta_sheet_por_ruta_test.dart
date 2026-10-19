// La hoja mide la distancia al bus por su recorrido, no en línea recta
// (A2, 2026-10-08), y a un bus que ya pasó el punto le cuenta la vuelta
// siguiente: no se sabe qué sentido espera la persona (dueño, 2026-10-08).
// La ruta es una U de 1500 m de ida, 400 m de lado y 1500 m de vuelta, en
// metros alrededor del pin; las cifras salen del dibujo, a mano.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

const _lat = 6.2442;
const _lon = -75.5812;

GeoPoint _m(double x, double y) => GeoPoint(
      lat: _lat + y / 111320,
      lon: _lon + x / (111320 * math.cos(_lat * math.pi / 180)),
    );

void main() {
  SharedPreferences.setMockInitialValues({});

  Future<void> montar(WidgetTester tester,
      {required GeoPoint bus,
      required double rumbo,
      required GeoPoint pin,
      bool circular = false}) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([
          BusPosition(
            busId: 'A-1',
            routeId: 'R1',
            lat: bus.lat,
            lon: bus.lon,
            heading: rumbo,
            speedKmh: 30,
            timestamp: DateTime.now(),
            isGhostBus: false,
          ),
        ]),
      ),
      routeTrajectoryProvider.overrideWith(
        (ref, routeId) => RouteTrajectory(
          routeId: routeId,
          routeName: 'Ruta 1',
          points: [
            _m(0, 0),
            _m(1500, 0),
            _m(1500, 400),
            _m(0, 400),
            if (circular) _m(0, 0),
          ],
        ),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: EtaBottomSheet())),
      ),
    );
    await tester.pump();
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      UserLocationState(
        mode: UserLocationMode.manual,
        lat: pin.lat,
        lon: pin.lon,
      ),
    );
    container
        .read(selectedRouteProvider.notifier)
        .select(const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'));
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pumpAndSettle();
  }

  testWidgets('la cifra es la distancia por la ruta, no la recta',
      (tester) async {
    // Recta: √(500² + 300²) ≈ 583 m. Por la ruta: 300 + 500 = 800 m.
    await montar(tester, bus: _m(1500, 100), rumbo: 0, pin: _m(1000, 400));

    expect(find.bySemanticsLabel(RegExp(r'^A (79\d|80\d) metros de ti$')),
        findsOneWidget);
  });

  testWidgets('un bus que ya pasó el punto no cuenta la vuelta entera',
      (tester) async {
    // La U cerrada: 3800 m. El bus en el 2650, el pin en el 1700: 950 hacia
    // atrás, no 2850 hasta la vuelta siguiente (en recta, 776).
    await montar(tester,
        bus: _m(750, 400), rumbo: 270, pin: _m(1500, 200), circular: true);

    expect(find.bySemanticsLabel(RegExp(r'^A 9[45]\d metros de ti$')),
        findsOneWidget);
    expect(find.textContaining('ya pasó'), findsNothing);
    expect(find.text('Avisarme cuando esté cerca'), findsOneWidget);
  });
}
