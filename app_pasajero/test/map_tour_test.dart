import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/location_status_chip.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_tour_overlay.dart';

/// Estado de ubicación fijo (GPS con posición) sin tocar geolocator.
class _FakeLocation extends StateNotifier<UserLocationState>
    implements UserLocationNotifier {
  _FakeLocation()
      : super(const UserLocationState(
          mode: UserLocationMode.gps,
          lat: 11.0041,
          lon: -74.8070,
        ));

  bool fixedPin = false;

  @override
  void setManualPin(double lat, double lon) {
    fixedPin = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('mapTourProvider', () {
    test('se muestra la primera vez y queda visto para siempre', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(mapTourProvider.notifier).maybeShow();
      expect(container.read(mapTourProvider), isTrue);

      await container.read(mapTourProvider.notifier).markSeen();
      expect(container.read(mapTourProvider), isFalse);

      // Nuevo contenedor (otro arranque de la app): no vuelve a salir.
      final again = ProviderContainer();
      addTearDown(again.dispose);
      await again.read(mapTourProvider.notifier).maybeShow();
      expect(again.read(mapTourProvider), isFalse);
    });

    test('no se muestra si el flag ya está en prefs', () async {
      SharedPreferences.setMockInitialValues({'map_tour_seen': true});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(mapTourProvider.notifier).maybeShow();
      expect(container.read(mapTourProvider), isFalse);
    });
  });

  group('MapTourOverlay', () {
    Future<void> pumpOverlay(WidgetTester tester, VoidCallback onDone) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const SizedBox.expand(),
                MapTourOverlay(
                  target: const Rect.fromLTWH(20, 60, 320, 60),
                  onDone: onDone,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('muestra la burbuja y el hueco alrededor de la píldora',
        (tester) async {
      var done = false;
      await pumpOverlay(tester, () => done = true);

      expect(find.byKey(const ValueKey('tour_bubble')), findsOneWidget);
      expect(find.text('Elige tu ruta'), findsOneWidget);
      expect(find.text('Entendido'), findsOneWidget);
      expect(
        find.textContaining('Toca la píldora de arriba'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('tour_scrim')), findsOneWidget);
      expect(done, isFalse);
    });

    testWidgets('Entendido cierra el tour', (tester) async {
      var done = false;
      await pumpOverlay(tester, () => done = true);

      await tester.tap(find.byKey(const ValueKey('tour_ok')));
      await tester.pump();
      expect(done, isTrue);
    });

    testWidgets('tocar la parte oscura cierra el tour', (tester) async {
      var done = false;
      await pumpOverlay(tester, () => done = true);

      // Punto lejos de la burbuja (que aparece debajo del hueco) y del hueco:
      // esquina superior izquierda.
      await tester.tapAt(const Offset(8, 8));
      await tester.pump();
      expect(done, isTrue);
    });
  });

  group('LocationStatusChip con GPS activo', () {
    testWidgets('ofrece "Fijar" y clava el pin en la posición actual',
        (tester) async {
      final location = _FakeLocation();
      final container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => location),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: LocationStatusChip()),
            ),
          ),
        ),
      );

      expect(find.text('Usando tu ubicación'), findsOneWidget);
      final fix = find.text('Fijar');
      expect(fix, findsOneWidget);

      await tester.tap(fix);
      await tester.pump();
      expect(location.fixedPin, isTrue);
    });

    testWidgets('en modo manual ofrece Quitar para volver al GPS',
        (tester) async {
      final container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _FakeLocation()),
      ]);
      addTearDown(container.dispose);
      final notifier =
          container.read(userLocationProvider.notifier) as _FakeLocation;
      notifier.state = const UserLocationState(
        mode: UserLocationMode.manual,
        lat: 10.9,
        lon: -74.9,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: LocationStatusChip()),
            ),
          ),
        ),
      );

      expect(find.text('Con tu ubicación'), findsOneWidget);
      expect(find.text('Quitar'), findsOneWidget);
    });
  });
}