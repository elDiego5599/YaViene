// El mapa del panel dibuja el recorrido de la ruta elegida, como el del
// pasajero: verde sobre orla blanca (`EstiloRuta` en app_pasajero). Antes
// solo el pasajero lo pintaba, y en el panel los buses flotaban sobre la
// ciudad sin la calle por la que van (dueño, 2026-10-07).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/control_map.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;
import 'package:ya_viene_core/core/providers/map_providers.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show EstiloRuta;

class _FakeFleetApi extends FleetApi {
  _FakeFleetApi() : super(baseUrl: 'http://localhost:3000');

  @override
  Future<List<FleetBus>> fetchPositions(String? token) async => const [];

  @override
  Future<List<FleetRoute>> fetchRoutes(String? token) async => const [];
}

class _Flota extends FleetNotifier {
  _Flota(super.ref, String? ruta, {String? rutaBus})
    : super(api: _FakeFleetApi()) {
    state = FleetState(
      routeFilter: ruta,
      buses: rutaBus == null
          ? const {}
          : {
              'B-1': const FleetBus(
                busId: 'B-1',
                companyId: 'c-1',
                routeId: 'R-101',
                visible: true,
                online: true,
                lat: 10.9,
                lon: -74.8,
              ),
            },
      selectedBusId: rutaBus == null ? null : 'B-1',
    );
  }
}

void main() {
  late Directory cache;
  setUpAll(() {
    cache = Directory.systemTemp.createTempSync('panel-ruta-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.path,
        );
  });
  tearDownAll(() => cache.deleteSync(recursive: true));

  Future<void> montar(
    WidgetTester tester,
    String? ruta, {
    String? rutaBus,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendUrlProvider.overrideWith(
            () => BackendUrl.fija('http://localhost:3000'),
          ),
          fleetProvider.overrideWith(
            (ref) => _Flota(ref, ruta, rutaBus: rutaBus),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ControlMap()),
        ),
      ),
    );
    // El recorrido sale de un asset: se lee fuera del reloj falso.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }

  // El mapa deja pendiente el reintento del estilo (en pruebas no llega).
  Future<void> desmontar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  test('el panel trae los recorridos: los mismos del pasajero', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final rutas = await c.read(rutasSobusaProvider.future);
    expect(
      rutas.map((r) => r.routeId),
      containsAll(['R-101', 'R-106', 'R-107', 'R-110']),
    );
    expect(rutas.every((r) => r.waypoints.length > 1), isTrue);
  });

  testWidgets('con una ruta elegida pinta su recorrido bajo los buses', (
    tester,
  ) async {
    await montar(tester, 'R-101');

    final capas = find.byType(PolylineLayer);
    expect(capas, findsOneWidget);
    final lineas = tester.widget<PolylineLayer>(capas).polylines;
    expect(lineas, hasLength(2), reason: 'la orla y la línea');
    final [orla, linea] = lineas;
    expect(orla.color, Colors.white.withValues(alpha: 0.95));
    expect(orla.strokeWidth, 8);
    expect(linea.color, const Color(0xFFE86A5E));
    expect(linea.strokeWidth, 4);
    expect(orla.strokeWidth, EstiloRuta.orla.lineWidth);
    expect(linea.strokeWidth, EstiloRuta.linea.lineWidth);
    expect(EstiloRuta.orla.lineColor, '#FFFFFF');
    expect(EstiloRuta.linea.lineColor, '#00A859');
    expect(EstiloRuta.lineaPanel.lineColor, '#E86A5E');
    for (final l in lineas) {
      expect(l.strokeCap, StrokeCap.round);
      expect(l.strokeJoin, StrokeJoin.round);
    }

    // El primer punto es el de rutas.json, no uno inventado.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ControlMap)),
    );
    final r101 = (await tester.runAsync(
      () => container.read(routeTrajectoryProvider('R-101').future),
    ))!;
    expect(
      linea.points.first,
      LatLng(r101.points.first.lat, r101.points.first.lon),
    );
    expect(linea.points, hasLength(r101.points.length));

    final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    final terminalMarkers = markerLayer.markers
        .where((marker) => marker.child.key == const ValueKey('terminal:R-101'))
        .toList();
    expect(terminalMarkers, hasLength(1));
    expect(
      terminalMarkers.single.point,
      LatLng(r101.points.first.lat, r101.points.first.lon),
      reason: 'el terminal queda fijo en el primer punto del recorrido',
    );

    // Debajo de los buses: el recorrido va antes en la pila del mapa.
    final hijos = tester.widget<FlutterMap>(find.byType(FlutterMap)).children;
    expect(
      hijos.indexWhere((w) => w is PolylineLayer),
      lessThan(hijos.indexWhere((w) => w is MarkerLayer)),
    );
    await desmontar(tester);
  });

  testWidgets('la ruta del bus seleccionado también se dibuja', (tester) async {
    await montar(tester, null, rutaBus: 'R-101');
    expect(find.byType(PolylineLayer), findsOneWidget);
    final lineas = tester
        .widget<PolylineLayer>(find.byType(PolylineLayer))
        .polylines;
    expect(lineas, hasLength(2));
    expect(lineas.last.color, const Color(0xFFE86A5E));
    await desmontar(tester);
  });

  testWidgets('sin ruta elegida no hay recorrido', (tester) async {
    await montar(tester, null);
    expect(find.byType(PolylineLayer), findsNothing);
    await desmontar(tester);
  });

  testWidgets('una ruta sin recorrido (dada de alta en el panel) no pinta '
      'nada', (tester) async {
    await montar(tester, 'R-NUEVA');
    expect(find.byType(PolylineLayer), findsNothing);
    await desmontar(tester);
  });
}
