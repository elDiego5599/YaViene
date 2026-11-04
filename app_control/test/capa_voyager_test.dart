// Las teselas pintadas del mapa caben en disco (dueño, 2026-11-03, «carga
// muy lento»). `vector_map_tiles` guarda por defecto 50 MB, y solo la ciudad
// a zoom 15 ya ocupa unos 50: el panel borraba lo que había pintado y lo
// volvía a bajar y a pintar al moverse.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart'
    show ThemeReader;
import 'package:ya_viene_control/features/fleet/presentation/widgets/capa_voyager.dart';

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
        'paint': {'background-color': '#f4f2ee'},
      },
      {
        'id': 'water',
        'type': 'fill',
        'source': 'carto',
        'source-layer': 'water',
        'paint': {'fill-color': '#a4d2f4'},
      },
    ],
  }),
  providers: TileProviders({'carto': _SinTeselas()}),
);

void main() {
  late Directory cache;

  setUpAll(() {
    cache = Directory.systemTemp.createTempSync('panel-teselas-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.path,
        );
  });
  tearDownAll(() => cache.deleteSync(recursive: true));

  testWidgets('la caché de disco del mapa guarda la ciudad entera', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterMap(
          options: const MapOptions(initialCenter: LatLng(10.98, -74.81)),
          children: [CapaVoyager(estilo: _estiloMinimo())],
        ),
      ),
    );
    final capa = tester.widget<VectorTileLayer>(find.byType(VectorTileLayer));
    expect(capa.fileCacheMaximumSizeInBytes, 256 * 1024 * 1024);
    // La carpeta es la de siempre: en macOS ya vive en Library/Caches, y así
    // no se pierde lo que el panel ya tiene guardado.
    expect(capa.cacheFolder, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });

  // Las teselas de CARTO son de 512 px, como las de Mapbox, y el estilo
  // cuenta sus zooms así. Con el desfase de fábrica (teselas de 256) el panel
  // pintaba cada vista con el estilo de un zoom más cerca: calles gordas y
  // apretadas y el papel de la ciudad, que se mide en metros, al doble
  // (dueño, 2026-11-03, «toca acercarme mucho para que se vea bien»). El
  // pasajero, con MapLibre, ya las leía bien.
  testWidgets('lee las teselas de 512 px como el pasajero', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterMap(
          options: const MapOptions(initialCenter: LatLng(10.98, -74.81)),
          children: [CapaVoyager(estilo: _estiloMinimo())],
        ),
      ),
    );
    final capa = tester.widget<VectorTileLayer>(find.byType(VectorTileLayer));
    expect(capa.tileOffset.zoomOffset, TileOffset.mapbox.zoomOffset);
    expect(TileOffset.mapbox.zoomOffset, -1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}
