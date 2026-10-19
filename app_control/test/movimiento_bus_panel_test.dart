// Los buses del panel se deslizan entre dos fijaciones GPS como en el
// pasajero (`BusMotion`, lo que tardó la fijación, de 1 a 15 s). Antes
// saltaban de un punto al siguiente en cada paquete (dueño, 2026-10-07).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/control_map.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

class _FakeFleetApi extends FleetApi {
  _FakeFleetApi() : super(baseUrl: 'http://localhost:3000');

  @override
  Future<List<FleetBus>> fetchPositions(String? token) async => const [];

  @override
  Future<List<FleetRoute>> fetchRoutes(String? token) async => const [];
}

FleetBus _bus(double lon, double heading, {int? capturedAt}) => FleetBus(
  busId: 'B-1',
  companyId: 'c-1',
  visible: true,
  online: true,
  lat: 10.9639,
  lon: lon,
  heading: heading,
  capturedAt: capturedAt,
);

/// Un bus en línea que avanza cuando la prueba lo pide.
class _FlotaMovil extends FleetNotifier {
  _FlotaMovil(super.ref) : super(api: _FakeFleetApi()) {
    state = FleetState(buses: {'B-1': _bus(-74.80, 80)});
  }

  void avanzar() => state = FleetState(buses: {'B-1': _bus(-74.79, 100)});

  void seguir() => state = FleetState(buses: {'B-1': _bus(-74.78, 100)});

  /// Dos fijaciones de un GPS real, capturadas con 8 s de diferencia.
  void conGps() =>
      state = FleetState(buses: {'B-1': _bus(-74.80, 80, capturedAt: 0)});
  void ochoSegundosDespues() =>
      state = FleetState(buses: {'B-1': _bus(-74.79, 80, capturedAt: 8000)});
}

void main() {
  late Directory cache;
  setUpAll(() {
    cache = Directory.systemTemp.createTempSync('panel-movimiento-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.path,
        );
  });
  tearDownAll(() => cache.deleteSync(recursive: true));

  Future<ProviderContainer> montar(
    WidgetTester tester, {
    bool reducido = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        backendUrlProvider.overrideWith(
          () => BackendUrl.fija('http://localhost:3000'),
        ),
        fleetProvider.overrideWith(_FlotaMovil.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(1200, 800),
            disableAnimations: reducido,
          ),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ControlMap()),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Marker marcador(WidgetTester tester) =>
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single;

  double rumbo(WidgetTester tester) => tester
      .widget<Transform>(
        find.byWidgetPredicate((w) => w is Transform && w.child is CustomPaint),
      )
      .transform
      .getRotation()
      .row0
      .y;

  // El mapa deja pendiente el reintento del estilo (en pruebas no llega).
  Future<void> desmontar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('el bus se desliza hasta su nueva posición en un segundo', (
    tester,
  ) async {
    final container = await montar(tester);
    expect(marcador(tester).point.longitude, closeTo(-74.80, 1e-9));

    (container.read(fleetProvider.notifier) as _FlotaMovil).avanzar();
    await tester.pump();
    expect(
      marcador(tester).point.longitude,
      closeTo(-74.80, 1e-4),
      reason: 'arranca donde estaba, no salta',
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(marcador(tester).point.longitude, closeTo(-74.795, 2e-4));
    // El giro va con resorte (`BusMotion.giro`, 800 ms): a medio tramo ya
    // casi mira a 100°, no a 90° como un giro lineal. sin(-100°) en la
    // matriz es -0,985; a 90° sería -1.
    expect(rumbo(tester), closeTo(-0.985, 5e-3));

    await tester.pump(const Duration(milliseconds: 600));
    expect(marcador(tester).point.longitude, closeTo(-74.79, 1e-9));
    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'el reloj se apaga cuando no queda tramo',
    );
    await desmontar(tester);
  });

  testWidgets('una fijación a medio tramo sigue desde donde se ve el bus', (
    tester,
  ) async {
    final container = await montar(tester);
    final flota = container.read(fleetProvider.notifier) as _FlotaMovil;
    flota.avanzar();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    flota.seguir();
    await tester.pump();
    expect(
      marcador(tester).point.longitude,
      closeTo(-74.795, 2e-4),
      reason: 'ni vuelve atrás ni salta a la fijación anterior',
    );
    await tester.pump(const Duration(milliseconds: 1100));
    expect(marcador(tester).point.longitude, closeTo(-74.78, 1e-9));
    await desmontar(tester);
  });

  testWidgets('con movimiento reducido salta en seco', (tester) async {
    final container = await montar(tester, reducido: true);
    (container.read(fleetProvider.notifier) as _FlotaMovil).avanzar();
    await tester.pump();
    expect(marcador(tester).point.longitude, closeTo(-74.79, 1e-9));
    await desmontar(tester);
  });

  // Con un GPS real llega una posición cada 5–15 s: deslizarse 1 s y
  // esperar quieto el resto hacía que el bus se congelara y saltara
  // (AUD16-05). El tramo dura lo que tardó la fijación.
  testWidgets('con fijaciones cada 8 s, el bus tarda 8 s en llegar', (
    tester,
  ) async {
    final container = await montar(tester);
    final flota = container.read(fleetProvider.notifier) as _FlotaMovil;
    flota.conGps();
    await tester.pump();
    flota.ochoSegundosDespues();
    await tester.pump();

    await tester.pump(const Duration(seconds: 4));
    expect(
      marcador(tester).point.longitude,
      closeTo(-74.795, 2e-4),
      reason: 'a los 4 s va por la mitad, no ya parado en la meta',
    );
    await tester.pump(const Duration(milliseconds: 4100));
    expect(marcador(tester).point.longitude, closeTo(-74.79, 1e-9));
    await desmontar(tester);
  });
}
