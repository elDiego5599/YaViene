// El panel pinta el mismo mapa que el pasajero (dueño, 2026-09-30).
//
// Antes eran dos mapas: el pasajero, Voyager de CARTO en vectores; el
// panel, las teselas de OpenStreetMap, con otra letra, otras vías y otros
// colores. Voyager no entraba en el panel porque CARTO ya solo da sus
// teselas rasterizadas —las que flutter_map sabía pintar— con «API KEY
// REQUIRED» encima; las vectoriales, las del pasajero, siguen limpias. Ahora
// el panel pinta esas mismas vectoriales con el mismo estilo.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart'
    show ThemeReader;
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/control_map.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;
import 'package:ya_viene_core/core/theme/estilo_mapa.dart';

class _FakeFleetApi extends FleetApi {
  _FakeFleetApi() : super(baseUrl: 'http://localhost:3000');

  @override
  Future<List<FleetBus>> fetchPositions(String? token) async => const [];

  @override
  Future<List<FleetRoute>> fetchRoutes(String? token) async => const [];
}

/// Un proveedor que nunca contesta: la prueba mira qué capa se monta, no
/// las teselas.
class _SinTeselas extends VectorTileProvider {
  @override
  int get maximumZoom => 14;

  @override
  int get minimumZoom => 1;

  @override
  TileProviderType get type => TileProviderType.vector;

  @override
  TileOffset get tileOffset => TileOffset.DEFAULT;

  @override
  Future<Uint8List> provide(TileIdentity tile) => Completer<Uint8List>().future;
}

/// Un estilo mínimo con la forma del de CARTO: una fuente `carto` y fondo.
Style _estiloMinimo() => Style(
  theme: ThemeReader().read({
    'version': 8,
    'sources': {
      'carto': {'type': 'vector'},
    },
    'layers': [
      {
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': '#fbf8f3'},
      },
      // Sin una capa que lea de `carto`, la capa del mapa no se arma.
      {
        'id': 'water',
        'type': 'fill',
        'source': 'carto',
        'source-layer': 'water',
        'paint': {'fill-color': '#d4dadc'},
      },
    ],
  }),
  providers: TileProviders({'carto': _SinTeselas()}),
);

Future<void> _montar(WidgetTester tester, Override estilo) async {
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
      estilo,
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
  await tester.pump();
}

/// La capa de vectores deja, al montarse, una limpieza de su caché a los
/// 3 s (`GridLayer.initState`) que no se cancela al desmontar: se deja
/// correr para que la prueba no termine con un reloj pendiente.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  late Directory cache;
  setUpAll(() {
    cache = Directory.systemTemp.createTempSync('panel-estilo-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.path,
        );
  });
  tearDownAll(() => cache.deleteSync(recursive: true));

  test('el estilo se pide a la misma dirección que usa el pasajero', () async {
    final pedidas = <String>[];
    final cliente = MockClient((pedido) async {
      pedidas.add(pedido.url.toString());
      final url = pedido.url.toString();
      if (url == kEstiloMapa) {
        return http.Response(
          jsonEncode({
            'version': 8,
            'sources': {
              'carto': {
                'type': 'vector',
                'url':
                    'https://tiles.basemaps.cartocdn.com/vector/carto.streets/v1/tiles.json',
              },
            },
            'layers': [
              {
                'id': 'background',
                'type': 'background',
                'paint': {'background-color': '#fbf8f3'},
              },
            ],
          }),
          200,
        );
      }
      if (url.endsWith('tiles.json')) {
        return http.Response(
          jsonEncode({
            'tiles': [
              'https://tiles-a.basemaps.cartocdn.com/vectortiles/carto.streets/v1/{z}/{x}/{y}.mvt',
            ],
            'maxzoom': 14,
          }),
          200,
        );
      }
      return http.Response('', 404);
    });

    final Style estilo = await http.runWithClient<Future<Style>>(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container.read(estiloMapaProvider.future);
    }, () => cliente);

    expect(pedidas.first, kEstiloMapa);
    expect(kEstiloMapa, contains('voyager'));
    expect(estilo.providers.tileProviderBySource.keys, ['carto']);
  });

  testWidgets('con el estilo listo, el mapa es de vectores y no de OSM', (
    tester,
  ) async {
    await _montar(
      tester,
      estiloMapaProvider.overrideWith((ref) async => _estiloMinimo()),
    );

    expect(find.byType(VectorTileLayer), findsOneWidget);
    // La capa de vectores monta por dentro su propio `TileLayer`, sin
    // dirección: lo que no puede quedar es uno que baje imágenes de OSM.
    final rasterizadas = tester
        .widgetList<TileLayer>(find.byType(TileLayer))
        .where((capa) => capa.urlTemplate != null);
    expect(rasterizadas, isEmpty);
    // CARTO pide su crédito igual que OpenStreetMap: los dos a la vista.
    expect(find.text('© CARTO © OpenStreetMap'), findsOneWidget);

    await _desmontar(tester);
  });

  testWidgets(
    'mientras llega el estilo, el fondo es el papel de Voyager y no gris',
    (tester) async {
      await _montar(
        tester,
        estiloMapaProvider.overrideWith((ref) => Completer<Style>().future),
      );

      expect(find.byType(VectorTileLayer), findsNothing);
      expect(find.byType(TileLayer), findsNothing);
      final mapa = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(mapa.options.backgroundColor, const Color(0xFFFBF8F3));

      await _desmontar(tester);
    },
  );

  testWidgets('si el estilo no llega, vuelve a pedirlo solo', (tester) async {
    var intentos = 0;
    await _montar(
      tester,
      estiloMapaProvider.overrideWith((ref) async {
        intentos++;
        if (intentos == 1) throw const SocketException('sin red');
        return _estiloMinimo();
      }),
    );

    expect(intentos, 1);
    expect(find.byType(VectorTileLayer), findsNothing);

    await tester.pump(ControlMap.reintentoEstilo);
    await tester.pump();
    await tester.pump();

    expect(intentos, 2);
    expect(find.byType(VectorTileLayer), findsOneWidget);

    await _desmontar(tester);
  });
}
