// El dibujo de la opción elegida en el mapa del planificador
// (docs/viaje-completo.md, sección 3.3). Lo que se dibuja sale de
// [TrazoDelViaje]; aquí solo se le da forma en MapLibre.
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'trazo_del_viaje.dart';

/// Las capas del viaje dentro de un mapa de MapLibre. Como `CapaRecarga`:
/// se instalan con cada estilo (MapLibre las pierde al recargarlo) y luego
/// solo se les cambia el dato.
///
/// El orden, de abajo arriba, es el de cualquier planificador (Citymapper,
/// Apple Maps): las caminatas punteadas, el tramo en bus con su orla bajo los
/// rótulos del mapa, y encima los puntos, que son lo que se lee.
class CapaViaje {
  static const _caminataFuente = 'viaje-caminata-source';
  static const _busFuente = 'viaje-bus-source';
  static const _paradasFuente = 'viaje-paradas-source';
  static const _origenFuente = 'viaje-origen-source';
  static const _destinoFuente = 'viaje-destino-source';

  static const _caminataCapa = 'viaje-caminata-layer';
  static const _orlaCapa = 'viaje-orla-layer';
  static const _busCapa = 'viaje-bus-layer';
  static const _paradasCapa = 'viaje-paradas-layer';
  static const _origenCapa = 'viaje-origen-layer';
  static const _destinoCapa = 'viaje-destino-layer';

  /// La caminata en `textSecondary` (#5E6B82): 5,0:1 sobre el papel #F4F2EE,
  /// se lee sin competir con el verde del bus. Puntos redondos de 4 pt cada
  /// 8 pt: el trazo de 4 con la punta redonda y un hueco de dos anchos.
  static const _gris = '#5E6B82';

  /// Azul de los botones (`AppColors.acento`): el mismo punto de «Desde» en
  /// la barra de arriba.
  static const _azul = '#1E56A8';

  /// Tinta de la marca (`AppColors.ink`): el destino, como el pin de la
  /// barra.
  static const _tinta = '#0B1628';

  static const _vacio = {'type': 'FeatureCollection', 'features': []};

  MapLibreMapController? _controller;
  bool _instalada = false;

  /// Crea las fuentes y las capas, vacías. [bajoRotulos] es la primera capa
  /// de rótulos del estilo (`primeraCapaDeRotulos`): la línea del bus va
  /// debajo para no tapar el nombre de las calles, como la ruta del mapa.
  Future<void> instalar(
    MapLibreMapController controller, {
    required String? bajoRotulos,
  }) async {
    _controller = controller;
    for (final fuente in [
      _caminataFuente,
      _busFuente,
      _paradasFuente,
      _origenFuente,
      _destinoFuente,
    ]) {
      await controller.addSource(
          fuente, const GeojsonSourceProperties(data: _vacio));
    }
    await controller.addLineLayer(
      _caminataFuente,
      _caminataCapa,
      const LineLayerProperties(
        lineColor: _gris,
        lineWidth: 4,
        lineCap: 'round',
        lineJoin: 'round',
        // En anchos de línea: 0 de trazo (la punta redonda hace el punto) y
        // 2 de hueco.
        lineDasharray: [0, 2],
      ),
      belowLayerId: bajoRotulos,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _busFuente,
      _orlaCapa,
      LineLayerProperties(
        lineColor: EstiloRuta.orla.lineColor,
        lineWidth: EstiloRuta.orla.lineWidth,
        lineOpacity: EstiloRuta.orla.lineOpacity,
        lineCap: EstiloRuta.orla.lineCap,
        lineJoin: EstiloRuta.orla.lineJoin,
      ),
      belowLayerId: bajoRotulos,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _busFuente,
      _busCapa,
      LineLayerProperties(
        lineColor: EstiloRuta.linea.lineColor,
        // Un punto más ancha que la ruta del mapa: aquí es lo único que hay
        // que seguir con el ojo.
        lineWidth: EstiloRuta.linea.lineWidth + 1,
        lineOpacity: EstiloRuta.linea.lineOpacity,
        lineCap: EstiloRuta.linea.lineCap,
        lineJoin: EstiloRuta.linea.lineJoin,
      ),
      belowLayerId: bajoRotulos,
      enableInteraction: false,
    );
    // Subida y bajada: las paradas de la ruta, blancas con su filo verde.
    await controller.addCircleLayer(
      _paradasFuente,
      _paradasCapa,
      CircleLayerProperties(
        circleRadius: EstiloRuta.paradaFija.circleRadius,
        circleColor: EstiloRuta.paradaFija.circleColor,
        circleStrokeWidth: EstiloRuta.paradaFija.circleStrokeWidth,
        circleStrokeColor: EstiloRuta.paradaFija.circleStrokeColor,
      ),
      enableInteraction: false,
    );
    await controller.addCircleLayer(
      _origenFuente,
      _origenCapa,
      const CircleLayerProperties(
        circleRadius: 7,
        circleColor: _azul,
        circleStrokeWidth: 3,
        circleStrokeColor: '#FFFFFF',
      ),
      enableInteraction: false,
    );
    await controller.addCircleLayer(
      _destinoFuente,
      _destinoCapa,
      const CircleLayerProperties(
        circleRadius: 8,
        circleColor: _tinta,
        circleStrokeWidth: 3,
        circleStrokeColor: '#FFFFFF',
      ),
      enableInteraction: false,
    );
    _instalada = true;
  }

  /// El estilo se recargó: las capas ya no existen.
  void olvidar() => _instalada = false;

  /// Dibuja [trazo], o los dos puntos solos si todavía no hay opción
  /// ([origen] y [destino] sueltos, cualquiera puede faltar).
  Future<void> dibujar({
    TrazoDelViaje? trazo,
    GeoPoint? origen,
    GeoPoint? destino,
  }) async {
    final c = _controller;
    if (c == null || !_instalada) return;
    final desde = trazo?.origen ?? origen;
    final hasta = trazo?.destino ?? destino;
    await c.setGeoJsonSource(
        _caminataFuente, lineasAGeoJson(trazo?.caminatas ?? const []));
    await c.setGeoJsonSource(
        _busFuente, lineasAGeoJson(trazo?.enBus ?? const []));
    await c.setGeoJsonSource(
      _paradasFuente,
      puntosAGeoJson([...?trazo?.subidas, ...?trazo?.bajadas]),
    );
    await c.setGeoJsonSource(
        _origenFuente, puntosAGeoJson([if (desde != null) desde]));
    await c.setGeoJsonSource(
        _destinoFuente, puntosAGeoJson([if (hasta != null) hasta]));
  }
}
