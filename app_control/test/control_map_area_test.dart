// Hasta dónde llega el mapa del panel.
//
// No tenía límite: se podía alejar hasta ver el planeta y arrastrar hasta
// Bogotá, y cada gesto pedía teselas de OpenStreetMap de sitios donde no hay
// un solo bus. Eso gasta red y cuadros, y el operador se pierde. Ahora el
// centro de la cámara no sale de un cuadrado sobre el área metropolitana
// y no se aleja más allá de verla entera.
//
// El cuadrado es más grande que el del pasajero (41 × 41 km, ver
// `app_pasajero/.../map_constants.dart`): el operador mira la flota entera
// en una pantalla de escritorio, y un bus que se sale de su ruta tiene que
// seguir a la vista.
import 'dart:io';
import 'dart:math' as math;

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

class _FakeFleetApi extends FleetApi {
  _FakeFleetApi() : super(baseUrl: 'http://localhost:3000');

  @override
  Future<List<FleetBus>> fetchPositions(String token) async => const [];

  @override
  Future<List<FleetRoute>> fetchRoutes(String token) async => const [];
}

/// Grados de latitud a kilómetros (constante: los meridianos no se estrechan).
const double _kmPorGradoLat = 110.574;

/// Grados de longitud a kilómetros a esa latitud.
double _kmPorGradoLon(double lat) => 111.320 * math.cos(lat * math.pi / 180);

Future<MapController> _montar(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      backendUrlProvider.overrideWith(
        () => BackendUrl.fija('http://localhost:3000'),
      ),
      fleetProvider.overrideWith(
        (ref) => FleetNotifier(ref, api: _FakeFleetApi()),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ControlMap()),
      ),
    ),
  );
  await tester.pump();
  return tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
}

Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  // El caché de teselas de flutter_map pide su carpeta al sistema; en
  // pruebas no hay quien conteste. Se le da una temporal.
  late Directory cache;
  setUpAll(() {
    cache = Directory.systemTemp.createTempSync('panel-mapa-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.path,
        );
  });
  tearDownAll(() => cache.deleteSync(recursive: true));

  final area = ControlMap.area;

  test('el área es un cuadrado de 60 km, más que los 41 del pasajero', () {
    final alto = (area.north - area.south) * _kmPorGradoLat;
    final ancho =
        (area.east - area.west) * _kmPorGradoLon((area.north + area.south) / 2);
    expect(
      (ancho - alto).abs() / alto,
      lessThan(0.02),
      reason: 'el área mide $ancho × $alto km',
    );
    expect(alto, closeTo(60, 1));
  });

  test('el área cubre el área metropolitana y los pueblos de alrededor', () {
    const sitios = <String, LatLng>{
      'Puerto Colombia': LatLng(11.004, -74.954),
      'Galapa': LatLng(10.897, -74.886),
      'Malambo': LatLng(10.859, -74.774),
      'Soledad': LatLng(10.918, -74.765),
      'Bocas de Ceniza': LatLng(11.108, -74.851),
      'Sabanagrande': LatLng(10.792, -74.756),
      'Tubará': LatLng(10.874, -74.979),
    };
    sitios.forEach((nombre, punto) {
      expect(
        area.contains(punto),
        isTrue,
        reason: '$nombre se queda fuera del mapa',
      );
    });
  });

  testWidgets('arrastrar hasta Bogotá deja la cámara en el borde del área', (
    tester,
  ) async {
    final mapa = await _montar(tester);

    mapa.move(const LatLng(4.711, -74.072), 12);
    await tester.pump();

    expect(
      area.contains(mapa.camera.center),
      isTrue,
      reason: 'la cámara quedó en ${mapa.camera.center}',
    );
    await _desmontar(tester);
  });

  testWidgets('no se aleja más allá del área metropolitana entera', (
    tester,
  ) async {
    final mapa = await _montar(tester);

    mapa.move(mapa.camera.center, 3);
    await tester.pump();

    expect(mapa.camera.zoom, ControlMap.zoomMinimo);
    await _desmontar(tester);
  });
}
