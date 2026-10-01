// La sombra del bus en el mapa del panel.
//
// El marcador gira con el rumbo (`Transform.rotate` en `_buildMarker`).
// La sombra de antes era del color del estado y estaba corrida hacia
// «abajo» del dibujo, que al girar quedaba detrás del bus: se leía como una
// estela verde. En el pasajero se veía roja y al dueño le pareció rarísima
// (2026-09-30). Las dos cápsulas son la misma, así que las dos llevan la
// misma sombra: gris y centrada.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Future<List<FleetBus>> fetchPositions(String token) async => const [];

  @override
  Future<List<FleetRoute>> fetchRoutes(String token) async => const [];
}

/// Una flota quieta con un solo bus en línea.
class _FlotaFija extends FleetNotifier {
  _FlotaFija(super.ref) : super(api: _FakeFleetApi()) {
    state = const FleetState(
      buses: {
        'B-1': FleetBus(
          busId: 'B-1',
          companyId: 'c-1',
          visible: true,
          online: true,
          lat: 10.9639,
          lon: -74.7964,
          heading: 90,
        ),
      },
    );
  }
}

void main() {
  // El caché de teselas de flutter_map pide su carpeta al sistema; en
  // pruebas no hay quien conteste. Se le da una temporal.
  late Directory cache;
  setUpAll(() {
    cache = Directory.systemTemp.createTempSync('panel-sombra-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.path,
        );
  });
  tearDownAll(() => cache.deleteSync(recursive: true));

  testWidgets('la sombra del bus en línea es neutra y pareja', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        backendUrlProvider.overrideWith(
          () => BackendUrl.fija('http://localhost:3000'),
        ),
        fleetProvider.overrideWith(_FlotaFija.new),
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

    final pintor = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .singleWhere((p) => p.runtimeType.toString() == '_FlatBusPainter')!;

    // Se pinta a 120 × 120 para tener resolución: la cápsula mide 90 de
    // alto (0,75 del lado) y 48 de ancho, de 36 a 84 y de 15 a 105. El
    // borde blanco sale 1,9 por fuera, así que se mira desde 3.
    late final ByteData datos;
    await tester.runAsync(() async {
      final grabadora = ui.PictureRecorder();
      pintor.paint(Canvas(grabadora), const Size.square(120));
      final imagen = await grabadora.endRecording().toImage(120, 120);
      datos = (await imagen.toByteData())!;
    });
    (int, int, int, int) pixel(int x, int y) {
      final i = (y * 120 + x) * 4;
      return (
        datos.getUint8(i),
        datos.getUint8(i + 1),
        datos.getUint8(i + 2),
        datos.getUint8(i + 3),
      );
    }

    for (final d in [3, 4, 6]) {
      // La fila 15 − d cubre la franja entre d − 1 y d del borde de
      // arriba; su espejo abajo es la 104 + d (a la derecha, la 83 + d).
      final arriba = pixel(60, 15 - d);
      final abajo = pixel(60, 104 + d);
      final izquierda = pixel(36 - d, 60);
      final derecha = pixel(83 + d, 60);
      expect(
        (arriba.$4 - abajo.$4).abs(),
        lessThanOrEqualTo(2),
        reason: 'a $d del borde, arriba $arriba y abajo $abajo',
      );
      expect((izquierda.$4 - derecha.$4).abs(), lessThanOrEqualTo(2));
      for (final p in [arriba, abajo, izquierda, derecha]) {
        if (p.$4 == 0) continue;
        expect(
          (p.$1 - p.$2).abs(),
          lessThanOrEqualTo(8),
          reason: 'a $d del borde la sombra lleva color: $p',
        );
      }
    }
    // Y existe: el bus se despega del mapa.
    expect(pixel(60, 108).$4, greaterThan(0));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
