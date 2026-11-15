import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/recarga/capa_recarga.dart';

/// Un mapa de mentira que lleva la cuenta de lo que MapLibre tendría: las
/// fuentes y capas vivas, su visibilidad y los datos de la fuente. Un
/// `addSource` o `addLayer` con un id que ya existe falla como el nativo, y
/// [pausa] deja detener una instalación a medias para meter eventos dentro.
class _MapaFalso extends Fake implements MapLibreMapController {
  final fuentes = <String, int>{};
  final capas = <String>{};
  final visibles = <String, bool>{};
  final imagenes = <String>{};
  Completer<void>? pausa;

  Future<void> _esperar() async => pausa == null ? null : await pausa!.future;

  @override
  Future<void> addSource(String id, SourceProperties properties) async {
    await _esperar();
    if (fuentes.containsKey(id)) throw StateError('fuente repetida: $id');
    final datos = (properties as GeojsonSourceProperties).data as Map;
    fuentes[id] = (datos['features'] as List).length;
  }

  @override
  Future<void> addImage(String name, Uint8List bytes,
      [bool sdf = false]) async {
    imagenes.add(name);
  }

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    CircleLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {
    if (!capas.add(layerId)) throw StateError('capa repetida: $layerId');
    visibles[layerId] = true;
  }

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {
    if (!capas.add(layerId)) throw StateError('capa repetida: $layerId');
    visibles[layerId] = true;
  }

  @override
  Future<void> removeLayer(String id) async {
    capas.remove(id);
    visibles.remove(id);
  }

  @override
  Future<void> removeSource(String id) async => fuentes.remove(id);

  @override
  Future<void> setLayerVisibility(String id, bool visible) async {
    visibles[id] = visible;
  }

  @override
  Future<void> setGeoJsonSource(String id, Map<String, dynamic> geojson) async {
    fuentes[id] = geojson['features'].length as int;
  }

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {}
}

PuntoDeRecarga _punto(String id) => PuntoDeRecarga(
      id: id,
      nombre: 'DONDE TERESA',
      direccion: 'CLL 76',
      lat: 10.98,
      lon: -74.78,
      fuente: FuenteCitada(
        nombre: 'SIBUS',
        url: Uri.parse('https://sibusoficial.ambq.gov.co/'),
        fecha: DateTime.utc(2026, 11, 11),
      ),
    );

void main() {
  test('prender la capa mientras se instala no se pierde', () async {
    final mapa = _MapaFalso()..pausa = Completer<void>();
    final capa = CapaRecarga();
    final instalacion =
        capa.instalar(mapa, puntos: const [], visible: false, elegidoId: null);
    await capa.mostrar(true); // el dedo llegó antes de que terminara
    mapa.pausa!.complete();
    await instalacion;
    expect(mapa.capas, isNotEmpty);
    expect(mapa.visibles.values, everyElement(isTrue));
  });

  test('los puntos que llegan mientras se instala quedan en la fuente',
      () async {
    final mapa = _MapaFalso()..pausa = Completer<void>();
    final capa = CapaRecarga();
    final instalacion =
        capa.instalar(mapa, puntos: const [], visible: true, elegidoId: null);
    await capa.actualizarPuntos([_punto('a'), _punto('b')]);
    mapa.pausa!.complete();
    await instalacion;
    expect(mapa.fuentes['recarga-source'], 2);
  });

  test('un estilo recargado se reinstala encima de lo que dejó', () async {
    final mapa = _MapaFalso();
    final capa = CapaRecarga();
    await capa.instalar(mapa,
        puntos: [_punto('a')], visible: true, elegidoId: null);
    // MapLibre recarga el estilo: aquí las capas siguen, porque el nativo
    // las perdería sin avisar. Reinstalar no puede reventar con «repetida».
    await capa.instalar(mapa,
        puntos: [_punto('a')], visible: true, elegidoId: null);
    expect(mapa.fuentes['recarga-source'], 1);
    expect(mapa.visibles.values, everyElement(isTrue));
  });

  test('un fallo al instalar no tumba el mapa y se puede reintentar', () async {
    final mapa = _MapaFalso()..fuentes['recarga-source'] = 0;
    final capa = CapaRecarga();
    await capa.instalar(mapa, puntos: const [], visible: true, elegidoId: null);
    expect(mapa.capas, isNotEmpty);
  });
}
