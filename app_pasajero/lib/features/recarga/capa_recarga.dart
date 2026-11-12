import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../map/presentation/utils/bus_hit_test.dart';

/// Los puntos como GeoJSON para MapLibre. Solo llevan el id: el mapa no
/// pinta nombres de sitios ni negocios (el nombre vive en la ficha).
Map<String, dynamic> puntosAGeoJson(List<PuntoDeRecarga> puntos) => {
      'type': 'FeatureCollection',
      'features': [
        for (final p in puntos)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [p.lon, p.lat],
            },
            'properties': {'id': p.id},
          },
      ],
    };

/// El id que lleva un feature devuelto por MapLibre, si lo trae.
String? idDeFeature(Map<dynamic, dynamic> feature) {
  final id = (feature['properties'] as Map?)?['id'];
  return id is String ? id : null;
}

/// La capa de puntos de recarga dentro del mapa de MapLibre.
///
/// Vive aparte de `MapWidget` para que el mapa solo tenga que instalarla,
/// sincronizarla y preguntarle qué punto cayó bajo el dedo. Son puntos
/// pequeños y sin rótulo, en el azul de los botones con filo blanco, bajo los
/// buses: los buses son lo que la app enseña.
class CapaRecarga {
  static const _fuenteId = 'recarga-source';
  static const _capaId = 'recarga-layer';
  static const _elegidoCapaId = 'recarga-elegido-layer';

  /// Radio de toque en puntos lógicos: el toque mínimo de Apple (44) partido
  /// en dos, para que dos puntos juntos no se roben el dedo.
  static const double radioDeToque = 24;

  /// Bajo el halo del bus elegido: encima de la ruta y de las paradas, debajo
  /// de todo lo que se mueve.
  static const _bajoCapaId = 'bus-selected-halo-layer';

  /// Azul de los botones (`AppColors.acento`), 7,1:1 con el filo blanco.
  static const _azul = '#1E56A8';

  MapLibreMapController? _controller;
  bool _instalada = false;

  /// Crea la fuente y las dos capas (los puntos y el aro del elegido), ambas
  /// apagadas. Se llama con cada estilo nuevo: MapLibre las pierde al
  /// recargarlo.
  Future<void> instalar(
    MapLibreMapController controller, {
    required List<PuntoDeRecarga> puntos,
    required bool visible,
    required String? elegidoId,
  }) async {
    _controller = controller;
    await controller.addSource(
      _fuenteId,
      GeojsonSourceProperties(data: puntosAGeoJson(puntos)),
    );
    await controller.addCircleLayer(
      _fuenteId,
      _capaId,
      const CircleLayerProperties(
        circleColor: _azul,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 1.5,
        // 2 pt a zoom 11 (la ciudad entera) hasta 7 pt a zoom 16: ni un
        // polvo ni una mancha.
        circleRadius: [
          'interpolate',
          ['linear'],
          ['zoom'],
          11,
          2.5,
          14,
          4.5,
          16,
          7,
        ],
      ),
      belowLayerId: _bajoCapaId,
      enableInteraction: false,
    );
    await controller.addCircleLayer(
      _fuenteId,
      _elegidoCapaId,
      const CircleLayerProperties(
        circleColor: _azul,
        circleOpacity: 0.18,
        circleStrokeColor: _azul,
        circleStrokeWidth: 2,
        circleRadius: 14,
      ),
      belowLayerId: _bajoCapaId,
      filter: _filtroDe(elegidoId),
      enableInteraction: false,
    );
    _instalada = true;
    await mostrar(visible);
  }

  /// El estilo se recargó: las capas ya no existen.
  void olvidar() => _instalada = false;

  Future<void> mostrar(bool visible) async {
    final c = _controller;
    if (c == null || !_instalada) return;
    await c.setLayerVisibility(_capaId, visible);
    await c.setLayerVisibility(_elegidoCapaId, visible);
  }

  Future<void> actualizarPuntos(List<PuntoDeRecarga> puntos) async {
    final c = _controller;
    if (c == null || !_instalada) return;
    await c.setGeoJsonSource(_fuenteId, puntosAGeoJson(puntos));
  }

  Future<void> elegir(String? id) async {
    final c = _controller;
    if (c == null || !_instalada) return;
    await c.setFilter(_elegidoCapaId, _filtroDe(id));
  }

  /// El id del punto bajo el dedo, o null. [toque] viene en las unidades del
  /// mapa nativo y [escala] es [escalaDelMapa]. Se piden al mapa los puntos
  /// pintados alrededor del toque y se escoge el centro más cercano, igual
  /// que con los buses.
  Future<String?> puntoEnToque(
    math.Point<double> toque, {
    required double escala,
    required Map<String, PuntoDeRecarga> porId,
  }) async {
    final c = _controller;
    if (c == null || !_instalada) return null;
    final lado = radioDeToque * 2 * escala;
    final encontrados = await c.queryRenderedFeaturesInRect(
      Rect.fromCenter(
        center: Offset(toque.x, toque.y),
        width: lado,
        height: lado,
      ),
      [_capaId],
      null,
    );
    final candidatos = <BusScreenPoint>[];
    for (final feature in encontrados) {
      final id = idDeFeature(feature as Map);
      final punto = id == null ? null : porId[id];
      if (punto == null) continue;
      final pantalla = await c.toScreenLocation(LatLng(punto.lat, punto.lon));
      candidatos.add(BusScreenPoint(
          busId: punto.id, offset: aPuntoLogico(pantalla, escala)));
    }
    return nearestBusId(
      aPuntoLogico(toque, escala),
      candidatos,
      maxDistance: radioDeToque,
    );
  }

  /// Un filtro que no encaja con nadie cuando no hay punto elegido.
  static List<Object> _filtroDe(String? id) => [
        '==',
        ['get', 'id'],
        id ?? ''
      ];
}
