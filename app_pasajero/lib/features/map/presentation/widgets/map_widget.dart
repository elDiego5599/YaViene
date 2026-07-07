/// =============================================================================
/// WIDGET: MapWidget (Integración Real con Mapbox)
///
/// PRINCIPIO DE DISEÑO: Cero reconstrucciones de Flutter por tick GPS.
///
/// El bus se mueve en el mapa actualizando ÚNICAMENTE el GeoJsonSource nativo
/// de Mapbox. Esto significa que el motor de renderizado de Mapbox (C++ / Metal /
/// OpenGL) redibuja solo el marcador del bus en la GPU, sin que el árbol de
/// widgets de Flutter sea tocado.
///
/// Flujo de datos de posición:
///   movingBusProvider (Stream)
///     → ref.listen() en initState de ConsumerStatefulWidget
///       → _updateBusSourceData(position)  ← solo esto se ejecuta en cada tick
///         → mapboxMap.style.setStyleSourceProperty('bus-source', 'data', geoJson)
///           → Mapbox renderiza el marcador rotado y coloreado en la GPU
///
/// SIN setState. SIN reconstrucción del árbol de widgets.
///
/// Capas de Mapbox creadas (en orden de renderizado inferior a superior):
///   1. route-source     → LineLayer 'route-line'    (polilínea azul institucional)
///   2. stops-fija       → CircleLayer 'stops-fija-layer'  (marcadores sólidos)
///   3. stops-informal   → FillLayer 'stops-informal-layer' (halos semitransparentes)
///   4. bus-source       → SymbolLayer 'bus-layer'   (marcador rotado con heading)
/// =============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/bus_position.dart';
import '../../../../core/models/bus_stop.dart';
import '../../../../core/models/route_trajectory.dart';
import '../../../../core/providers/map_providers.dart';
import '../../../../core/providers/app_providers.dart' show selectedRouteProvider;

final _selectedRouteForMapProvider = Provider((ref) {
  return ref.watch(selectedRouteProvider);
});

// ── IDs de capas y sources (constantes para evitar strings mágicos) ──────────
const _kRouteSourceId = 'route-source';
const _kRouteLayerId = 'route-line';
const _kStopsFijaSourceId = 'stops-fija-source';
const _kStopsFijaLayerId = 'stops-fija-layer';
const _kStopsInformalSourceId = 'stops-informal-source';
const _kStopsInformalLayerId = 'stops-informal-layer';
const _kBusSourceId = 'bus-source';
const _kBusLayerId = 'bus-layer';
const _kBusIconId = 'bus-icon-active';
const _kBusGhostIconId = 'bus-icon-ghost';

// ── Token de Mapbox ───────────────────────────────────────────────────────────
// IMPORTANTE: Reemplazar 'YOUR_MAPBOX_TOKEN' con tu token real de Mapbox.
// El token se puede gestionar via:
//   - Android: AndroidManifest.xml → <meta-data android:name="MAPBOX_ACCESS_TOKEN".../>
//   - iOS: Info.plist → MBXAccessToken
// O bien cargarlo desde variables de entorno con flutter_dotenv en producción.
const _kMapboxToken = 'YOUR_MAPBOX_TOKEN';

class MapWidgetView extends ConsumerStatefulWidget {
  /// ID de la ruta seleccionada. Cuando cambia, se recargan trayectoria y paradas.
  final String? routeId;

  const MapWidgetView({super.key, this.routeId});

  @override
  ConsumerState<MapWidgetView> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidgetView> {
  /// Controlador del mapa Mapbox. Disponible después de onMapCreated.
  MapboxMap? _mapboxMap;

  /// Flag para saber si las capas ya fueron inicializadas.
  bool _layersReady = false;

  // ── Ciclo de vida ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    try {
      MapboxOptions.setAccessToken(_kMapboxToken);
    } catch (_) {
      // En web, bool.fromEnvironment solo funciona como const;
      // Mapbox lanza UnsupportedError. Se ignora para el preview.
    }
  }

  @override
  void didUpdateWidget(MapWidgetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia la ruta seleccionada, recargar los datos del mapa
    if (oldWidget.routeId != widget.routeId && _layersReady) {
      _reloadMapData();
    }
  }

  // ── Callbacks del mapa ───────────────────────────────────────────────────────

  /// Llamado UNA SOLA VEZ cuando el mapa está listo para recibir capas.
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;



    // Cargar iconos del bus en la memoria del mapa
    await _loadBusIcons();

    // Inicializar sources y layers vacíos
    await _initializeMapSources();

    _layersReady = true;

    // Cargar datos si ya hay una ruta seleccionada
    if (widget.routeId != null) {
      await _reloadMapData();
    }

    // CRÍTICO: Escuchar el stream de posición del bus con ref.listen.
    // ref.listen NO reconstruye el widget. Llama _updateBusSourceData directamente.
    ref.listenManual(movingBusProvider, (previous, next) {
      next.whenData((position) => _updateBusSourceData(position));
    });
  }

  // ── Inicialización de capas ──────────────────────────────────────────────────

  /// Crea los 4 sources y sus layers en Mapbox. Los sources empiezan vacíos
  /// (FeatureCollection sin features) y se rellenan con datos reales después.
  Future<void> _initializeMapSources() async {
    final mapStyle = _mapboxMap!.style;
    const emptyCollection = '{"type":"FeatureCollection","features":[]}';

    // ── 1. Source y Layer de la Ruta (LineString) ─────────────────────────────
    await mapStyle.addSource(GeoJsonSource(
      id: _kRouteSourceId,
      data: emptyCollection,
    ));
    await mapStyle.addLayer(LineLayer(
      id: _kRouteLayerId,
      sourceId: _kRouteSourceId,
      lineColor: AppColors.primary.value, // Azul institucional
      lineWidth: 4.0,
      lineOpacity: 0.9,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));

    // ── 2. Source y Layer de Paradas Fijas (puntos sólidos) ───────────────────
    await mapStyle.addSource(GeoJsonSource(
      id: _kStopsFijaSourceId,
      data: emptyCollection,
    ));
    await mapStyle.addLayer(CircleLayer(
      id: _kStopsFijaLayerId,
      sourceId: _kStopsFijaSourceId,
      circleRadius: 7.0,
      circleColor: AppColors.background.value,  // Blanco interior
      circleStrokeWidth: 2.5,
      circleStrokeColor: AppColors.primary.value, // Borde azul institucional
    ));

    // ── 3. Source y Layer de Paradas Informales (halos semitransparentes) ─────
    // Se usa un círculo con radio proporcional al campo radio_m del GeoJSON.
    // El radio se expresa en píxeles en pantalla, no en metros reales.
    // En MVP 2, migrar a FillLayer con un polígono circulado en metros reales.
    await mapStyle.addSource(GeoJsonSource(
      id: _kStopsInformalSourceId,
      data: emptyCollection,
    ));
    await mapStyle.addLayer(CircleLayer(
      id: _kStopsInformalLayerId,
      sourceId: _kStopsInformalSourceId,
      circleRadius: 30.0,        // Aproximación visual del radio de influencia
      circleColor: AppColors.primary.value,
      circleOpacity: 0.12,       // Semitransparente: efecto halo
      circleStrokeWidth: 1.5,
      circleStrokeColor: AppColors.primary.value,
      circleStrokeOpacity: 0.3,
    ));

    // ── 4. Source y Layer del Bus (marcador con rotación) ─────────────────────
    await mapStyle.addSource(GeoJsonSource(
      id: _kBusSourceId,
      data: emptyCollection,
    ));
    await mapStyle.addLayer(SymbolLayer(
      id: _kBusLayerId,
      sourceId: _kBusSourceId,
      // El ícono del bus se elige basado en la propiedad 'isGhost' del GeoJSON
      // mediante una expresión data-driven de Mapbox.
      iconImageExpression: [
        'case',
        ['==', ['get', 'isGhost'], true],
        _kBusGhostIconId,    // Ícono gris si es bus fantasma
        _kBusIconId,          // Ícono azul si está activo
      ],
      iconSize: 1.2,
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
      // Rotación data-driven: lee el campo 'heading' del GeoJSON feature
      iconRotateExpression: ['get', 'heading'],
      iconRotationAlignment: IconRotationAlignment.MAP,
      // Sombra sutil bajo el ícono del bus
      iconHaloColor: Colors.black.withOpacity(0.15).value,
      iconHaloWidth: 3.0,
    ));
  }

  // ── Gestión de Iconos ────────────────────────────────────────────────────────

  /// Genera los dos íconos del bus programáticamente (sin depender de assets PNG).
  /// Ícono activo: azul institucional. Ícono fantasma: gris.
  Future<void> _loadBusIcons() async {
    final activeBytes = await _drawBusIcon(color: AppColors.primary);
    final ghostBytes = await _drawBusIcon(color: AppColors.busGhost);

    await _mapboxMap!.style.addStyleImage(
      _kBusIconId, 1.0, MbxImage(width: 48, height: 48, data: activeBytes),
      false, [], [], null,
    );
    await _mapboxMap!.style.addStyleImage(
      _kBusGhostIconId, 1.0, MbxImage(width: 48, height: 48, data: ghostBytes),
      false, [], [], null,
    );
  }

  /// Dibuja un ícono de bus en un Canvas de Flutter y lo retorna como bytes RGBA.
  /// Forma: óvalo + cabecera = silueta reconocible de un bus de perfil.
  Future<Uint8List> _drawBusIcon({required Color color}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 48.0;
    const half = size / 2;

    // Cuerpo del bus: rectángulo redondeado
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Sombra
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 12, 32, 28),
        const Radius.circular(6),
      ),
      shadowPaint,
    );

    // Cuerpo
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 8, 32, 28),
        const Radius.circular(6),
      ),
      bodyPaint,
    );

    // Ventanas (3 rectángulos blancos)
    final windowPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(9.0 + i * 10, 13, 8, 9),
          const Radius.circular(2),
        ),
        windowPaint,
      );
    }

    // Ruedas
    final wheelPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(14, 36), 5, wheelPaint);
    canvas.drawCircle(const Offset(30, 36), 5, wheelPaint);

    // Flecha de dirección (triángulo en la parte superior)
    final arrowPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    final arrowPath = Path()
      ..moveTo(half, 2)
      ..lineTo(half - 6, 10)
      ..lineTo(half + 6, 10)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  // ── Recarga de datos del mapa ────────────────────────────────────────────────

  /// Recarga la trayectoria y las paradas cuando cambia la ruta seleccionada.
  Future<void> _reloadMapData() async {
    if (_mapboxMap == null || widget.routeId == null) return;

    // Leer los datos de los providers (son FutureProviders con caché)
    final trajectoryAsync =
        ref.read(routeTrajectoryProvider(widget.routeId!));
    final stopsAsync =
        ref.read(busStopsProvider(widget.routeId!));

    trajectoryAsync.whenData((trajectory) => _updateRouteSource(trajectory));
    stopsAsync.whenData((stops) => _updateStopsSources(stops));
  }

  /// Actualiza el GeoJsonSource de la polilínea de la ruta.
  Future<void> _updateRouteSource(RouteTrajectory trajectory) async {
    if (_mapboxMap == null) return;
    final geoJson = jsonEncode(trajectory.toGeoJsonFeatureCollection());
    await _mapboxMap!.style.setStyleSourceProperty(
      _kRouteSourceId, 'data', geoJson,
    );

    // Centrar la cámara en el punto medio de la ruta
    final center = trajectory.center;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(center.lon, center.lat),
        ),
        zoom: 12.5,
        bearing: 0,
        pitch: 0,
      ),
      MapAnimationOptions(duration: 800, startDelay: 0),
    );
  }

  /// Divide las paradas en dos grupos y actualiza sus sources.
  Future<void> _updateStopsSources(List<BusStop> stops) async {
    if (_mapboxMap == null) return;

    final fijaStops = stops.where((s) => s.tipo == BusStopType.fija).toList();
    final informalStops =
        stops.where((s) => s.tipo == BusStopType.informal).toList();

    final fijaGeoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': fijaStops.map((s) => s.toGeoJsonFeature()).toList(),
    });
    final informalGeoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': informalStops.map((s) => s.toGeoJsonFeature()).toList(),
    });

    await _mapboxMap!.style.setStyleSourceProperty(
      _kStopsFijaSourceId, 'data', fijaGeoJson,
    );
    await _mapboxMap!.style.setStyleSourceProperty(
      _kStopsInformalSourceId, 'data', informalGeoJson,
    );
  }

  // ── Actualización de posición del bus (CRÍTICO: sin setState) ───────────────

  /// Actualiza la posición del bus en el mapa.
  /// ESTE MÉTODO SE LLAMA CADA SEGUNDO desde ref.listen.
  /// NO llama a setState. NO reconstruye ningún widget de Flutter.
  /// Solo actualiza el GeoJsonSource en el motor de Mapbox.
  Future<void> _updateBusSourceData(BusPosition position) async {
    if (_mapboxMap == null) return;

    final geoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [position.lon, position.lat],
          },
          'properties': {
            'busId': position.busId,
            'heading': position.heading,
            'speedKmh': position.speedKmh,
            'isGhost': position.shouldShowAsGhost,
          },
        }
      ],
    });

    await _mapboxMap!.style.setStyleSourceProperty(
      _kBusSourceId,
      'data',
      geoJson,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Observar la ruta seleccionada para recargar datos cuando cambie
    final selectedRoute = ref.watch(
      // Importado desde app_providers.dart
      // ignore: avoid_manual_providers_as_generated_provider_dependency
      _selectedRouteForMapProvider,
    );

    // Reaccionar al cambio de ruta de forma declarativa
    ref.listen(_selectedRouteForMapProvider, (_, next) {
      if (_layersReady && next != null) {
        _reloadMapData();
      }
    });

    return MapWidget(
      styleUri: MapboxStyles.LIGHT,
      onMapCreated: _onMapCreated,
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(-74.8070, 11.0041),
        ),
        zoom: 11.0,
      ),
    );
  }
}


