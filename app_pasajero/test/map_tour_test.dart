import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/location_status_chip.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_tour_overlay.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';

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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MapGuideNotifier', () {
    test('inicia en ubicación sin GPS y en búsqueda con GPS listo', () async {
      final withoutLocation = MapGuideNotifier();
      addTearDown(withoutLocation.dispose);
      await withoutLocation.initialize(
        userId: 'user-1',
        isNewUser: true,
        hasLocation: false,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      expect(withoutLocation.state.step, MapGuideStep.location);

      SharedPreferences.setMockInitialValues({});
      final withLocation = MapGuideNotifier();
      addTearDown(withLocation.dispose);
      await withLocation.initialize(
        userId: 'user-2',
        isNewUser: true,
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      expect(withLocation.state.step, MapGuideStep.search);
    });

    test('solo avanza cuando se completa el paso actualmente visible',
        () async {
      final guide = MapGuideNotifier();
      addTearDown(guide.dispose);
      await guide.initialize(
        userId: 'user-3',
        isNewUser: true,
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );

      await guide.complete(MapGuideStep.company);
      expect(guide.state.step, MapGuideStep.search);

      await guide.complete(MapGuideStep.search);
      expect(guide.state.step, MapGuideStep.company);

      await guide.complete(MapGuideStep.company);
      expect(guide.state.step, MapGuideStep.route);
      await guide.complete(MapGuideStep.route);
      expect(guide.state.step, MapGuideStep.launchBuses);
    });

    test('persiste el progreso y migra los flags del tour anterior', () async {
      SharedPreferences.setMockInitialValues({
        'map_tour_seen': true,
        'map_tour_bus_seen': true,
      });
      final guide = MapGuideNotifier();
      addTearDown(guide.dispose);
      await guide.initialize(
        userId: 'user-4',
        isNewUser: true,
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      expect(guide.state.step, MapGuideStep.search);

      await guide.complete(MapGuideStep.search);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('map_guide_step'), MapGuideStep.company.index);

      final resumed = MapGuideNotifier();
      addTearDown(resumed.dispose);
      await resumed.initialize(
        userId: 'user-4',
        isNewUser: false,
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      expect(resumed.state.step, MapGuideStep.search);
    });

    test('un login existente en otro dispositivo no activa la guía', () async {
      final guide = MapGuideNotifier();
      addTearDown(guide.dispose);
      await guide.initialize(
        userId: 'existing-account',
        isNewUser: false,
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      expect(guide.state.initialized, isTrue);
      expect(guide.state.step, isNull);
    });

    test('saltar persiste y reiniciar vuelve al inicio apropiado', () async {
      final guide = MapGuideNotifier();
      addTearDown(guide.dispose);
      await guide.initialize(
        userId: 'user-5',
        isNewUser: true,
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      await guide.skip();
      expect(guide.state.skipped, isTrue);
      expect(guide.state.step, isNull);

      await guide.restart(
        userId: 'user-5',
        hasLocation: false,
        locationSettled: true,
      );
      expect(guide.state.step, MapGuideStep.location);
    });
  });

  group('MapGuideOverlay', () {
    Future<void> pumpGuide(
      WidgetTester tester, {
      required VoidCallback onSkip,
      required ValueChanged<bool> onTargetTap,
      String? primaryLabel,
      VoidCallback? onPrimary,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () => onTargetTap(true),
                  child: const ColoredBox(
                    color: Color(0xFFF8FAFC),
                    child: SizedBox.expand(),
                  ),
                ),
                MapGuideOverlay(
                  target: const Rect.fromLTWH(160, 260, 100, 64),
                  title: 'Empieza aquí',
                  message: 'Toca la zona iluminada para continuar.',
                  icon: Icons.search_rounded,
                  stepIndex: 1,
                  stepCount: 8,
                  primaryLabel: primaryLabel,
                  onPrimary: onPrimary,
                  onSkip: onSkip,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
    }

    testWidgets('solo deja atravesar el objetivo y no cierra al tocar afuera',
        (tester) async {
      var skipped = false;
      var targetTap = false;
      await pumpGuide(
        tester,
        onSkip: () => skipped = true,
        onTargetTap: (_) => targetTap = true,
      );

      expect(find.text('Empieza aquí'), findsOneWidget);
      expect(find.text('2/8'), findsOneWidget);
      await tester.tapAt(const Offset(210, 290));
      expect(targetTap, isTrue);
      await tester.tapAt(const Offset(8, 8));
      expect(skipped, isFalse);
    });

    testWidgets('Saltar guía y acción primaria son explícitos', (tester) async {
      var skipped = false;
      var primary = false;
      await pumpGuide(
        tester,
        onSkip: () => skipped = true,
        onTargetTap: (_) {},
        primaryLabel: 'Continuar',
        onPrimary: () => primary = true,
      );

      await tester.tap(find.byKey(const ValueKey('guide_primary')));
      expect(primary, isTrue);
      await tester.tap(find.byKey(const ValueKey('guide_skip')));
      expect(skipped, isTrue);
    });
  });

  group('LocationStatusChip con GPS activo', () {
    testWidgets('ofrece Fijar y clava el pin en la posición actual',
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
      expect(find.text('Fijar'), findsOneWidget);
      await tester.tap(find.text('Fijar'));
      expect(location.fixedPin, isTrue);
    });
  });
}
