import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../providers/map_view_state.dart';
import '../providers/tracking_providers.dart'
    show
        activeAlertsProvider,
        busPositionsSourceProvider,
        nearbyRadiusMeters,
        selectedBusesProvider;
import '../providers/user_location_provider.dart';

class MapWidget extends ConsumerStatefulWidget {
  final String? routeId;
  const MapWidget({super.key, this.routeId});

  @override
  ConsumerState<MapWidget> createState() => _MapWidgetState();
}

/// Tramo de animación de un bus entre dos fijaciones GPS.
class _BusMotion {
  _BusMotion({
    required this.fromLat,
    required this.fromLon,
    required this.fromHeading,
    required this.toLat,
    required this.toLon,
    required this.toHeading,
    required this.start,
  });

  final double fromLat;
  final double fromLon;
  final double fromHeading;
  final double toLat;
  final double toLon;
  final double toHeading;
  final DateTime start;

  /// Duración del tramo: con fixes cada ~1s, un tramo de 1s da movimiento
  /// continuo y suave (sin esperas ni saltos).
  static const Duration duration = Duration(milliseconds: 1000);

  bool isFinished(DateTime now) => now.difference(start) >= duration;
}

class _MapWidgetState extends ConsumerState<MapWidget>
    with WidgetsBindingObserver {
  MapLibreMapController? _mapController;
  ProviderSubscription<AsyncValue<List<BusPosition>>>? _movingBusSubscription;
  ProviderSubscription<UserLocationState>? _userPinSubscription;
  ProviderSubscription<double>? _mapInsetSubscription;
  ProviderSubscription<AsyncValue<RouteTrajectory>>? _trajectorySub;
  ProviderSubscription<AsyncValue<List<BusStop>>>? _stopsSub;
  double _currentBottomInset = 0;
  bool _layersReady = false;
  bool _styleInitInFlight = false;
  bool _hasFitInitialRoute = false;
  bool _placeholderShown = true;
  Timer? _placeholderTimeout;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  /// Última posición cruda recibida por bus (para propiedades del ícono).
  final Map<String, BusPosition> _rawBuses = {};

  /// Tramo de animación en curso por bus (interpolación entre fixes).
  final Map<String, _BusMotion> _busMotions = {};
  Timer? _busAnimTimer;

  static const _kRouteSourceId = 'route-source';
  static const _kRouteLayerId = 'route-line';
  static const _kStopsFijaSourceId = 'stops-fija-source';
  static const _kStopsFijaLayerId = 'stops-fija-layer';
  static const _kStopsInformalSourceId = 'stops-informal-source';
  static const _kStopsInformalLayerId = 'stops-informal-layer';
  static const _kBusSourceId = 'bus-source';
  static const _kBusLayerId = 'bus-layer';
  /// Capas consideradas "el bus" al tocar: solo el ícono. El halo de selección
  /// NO cuenta: es grande y como los buses van sobre la ruta, tapar pines
  /// cerca de la línea azul era casi imposible con el halo en la detección.
  static const _kBusHitLayers = ['bus-layer'];
  static const _kBusIconId = 'bus-icon-active';
  static const _kBusGhostIconId = 'bus-icon-ghost';
  static const _kUserPinSourceId = 'user-pin-source';
  static const _kUserPinLayerId = 'user-pin-layer';
  static const _kUserPinIconId = 'user-pin-icon';
  static const _kUserRadiusSourceId = 'user-radius-source';
  static const _kUserRadiusFillLayerId = 'user-radius-fill-layer';
  static const _kUserRadiusLineLayerId = 'user-radius-line-layer';

  static final LatLngBounds _colombiaBounds = LatLngBounds(
    southwest: const LatLng(-4.227, -79.023),
    northeast: const LatLng(12.556, -66.869),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapInsetSubscription =
        ref.listenManual<double>(mapBottomInsetProvider, (previous, next) {
      _applyMapBottomInset(next);
    });
    // Red de seguridad: si el estilo no llega a cargar (p. ej. red lenta o
    // un fallo de MapLibre), el placeholder nunca debe quedarse para
    // siempre. Pasado el límite se funde y deja ver el mapa (o el fondo).
    _placeholderTimeout = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      if (!_layersReady && _placeholderShown) {
        setState(() => _placeholderShown = false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _placeholderTimeout?.cancel();
    _movingBusSubscription?.close();
    _userPinSubscription?.close();
    _mapInsetSubscription?.close();
    _trajectorySub?.close();
    _stopsSub?.close();
    _busAnimTimer?.cancel();
    _busAnimTimer = null;
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    ref.read(appLifecycleProvider.notifier).state = state;
  }

  void _setupBusSubscription(String routeId) {
    _movingBusSubscription?.close();
    // Cambio de ruta: sin animación, se pinta directo (los buses son otros).
    _rawBuses.clear();
    _busMotions.clear();
    _busAnimTimer?.cancel();
    _busAnimTimer = null;
    _movingBusSubscription =
        ref.listenManual(busPositionsSourceProvider(routeId), (previous, next) {
      if (!mounted) return;
      if (_lifecycleState != AppLifecycleState.resumed) return;
      next.whenData(_updateBusSourceData);
    }, fireImmediately: true);
  }

  void _teardownBusSubscription() {
    _movingBusSubscription?.close();
    _movingBusSubscription = null;
    _rawBuses.clear();
    _busMotions.clear();
    _busAnimTimer?.cancel();
    _busAnimTimer = null;
    if (_mapController != null && mounted) {
      const emptyGeoJson = {"type": "FeatureCollection", "features": []};
      _mapController!.setGeoJsonSource(_kBusSourceId, emptyGeoJson);
    }
  }

  void _setupUserPinSubscription() {
    _userPinSubscription?.close();
    _userPinSubscription = ref.listenManual<UserLocationState>(
        userLocationProvider, (previous, next) {
      if (!mounted) return;
      if (_layersReady) _updateUserPinSource(next);
    }, fireImmediately: true);
  }

  void _updateUserPinSource(UserLocationState state) {
    if (_mapController == null || !mounted) return;
    const emptyGeoJson = {"type": "FeatureCollection", "features": []};

    if (state.hasPosition) {
      _mapController!.setGeoJsonSource(_kUserRadiusSourceId, {
        'type': 'FeatureCollection',
        'features': [
          _radiusCircleFeature(
            state.lat!,
            state.lon!,
            nearbyRadiusMeters.toDouble(),
          ),
        ],
      });
      // Pin en el centro del usuario: con GPS activo o pin manual.
      _mapController!.setGeoJsonSource(_kUserPinSourceId, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [state.lon, state.lat]
            },
            'properties': const {},
          },
        ],
      });
      return;
    }
    _mapController!.setGeoJsonSource(_kUserPinSourceId, emptyGeoJson);
    _mapController!.setGeoJsonSource(_kUserRadiusSourceId, emptyGeoJson);
  }

  Map<String, dynamic> _radiusCircleFeature(
    double lat,
    double lon,
    double radiusMeters,
  ) {
    const steps = 48;
    final coordinates = <List<double>>[];
    for (var i = 0; i < steps; i++) {
      final angle = 2 * math.pi * i / steps;
      final dLat = (radiusMeters * math.cos(angle)) / 111320;
      final dLon = (radiusMeters * math.sin(angle)) /
          (111320 * math.cos(lat * math.pi / 180));
      coordinates.add([lon + dLon, lat + dLat]);
    }
    coordinates.add(coordinates.first);
    return {
      'type': 'Feature',
      'geometry': {'type': 'Polygon', 'coordinates': [coordinates]},
      'properties': const {},
    };
  }

  void _teardownRouteData() {
    _trajectorySub?.close();
    _trajectorySub = null;
    _stopsSub?.close();
    _stopsSub = null;
    if (_mapController == null || !mounted) return;
    const emptyGeoJson = {"type": "FeatureCollection", "features": []};
    _mapController!.setGeoJsonSource(_kRouteSourceId, emptyGeoJson);
    _mapController!.setGeoJsonSource(_kStopsFijaSourceId, emptyGeoJson);
    _mapController!.setGeoJsonSource(_kStopsInformalSourceId, emptyGeoJson);
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeId != widget.routeId && _layersReady) {
      _hasFitInitialRoute = false;
      if (widget.routeId != null) {
        _reloadMapData();
        _setupBusSubscription(widget.routeId!);
      } else {
        _teardownBusSubscription();
        _teardownRouteData();
      }
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;
  }

  Future<void> _onStyleLoadedCallback() async {
    if (!mounted || _layersReady || _styleInitInFlight) return;
    _styleInitInFlight = true;
    try {
      // Íconos de bus no fatales: si fallan (p. ej. PNG corrupto), el mapa
      // sigue funcionando y el placeholder debe fundirse igual.
      try {
        await _loadBusIcons();
      } catch (e) {
        debugPrint('MapWidget._loadBusIcons error: $e');
      }
      await _initializeMapSources();
      _layersReady = true;
      // CRÍTICO: el placeholder se construye según `_layersReady`; sin un
      // rebuild aquí se quedaría en "Preparando tu mapa…" aunque el estilo
      // ya haya cargado.
      if (mounted) setState(() {});
      await _applyMapBottomInset(ref.read(mapBottomInsetProvider),
          animated: false);
      _setupUserPinSubscription();
      if (widget.routeId != null) {
        _reloadMapData();
        _setupBusSubscription(widget.routeId!);
      }
    } catch (e) {
      debugPrint('MapWidget._onStyleLoadedCallback error: $e');
    } finally {
      _styleInitInFlight = false;
    }
  }

  Future<void> _initializeMapSources() async {
    if (_mapController == null) return;
    const emptyGeoJson = {"type": "FeatureCollection", "features": []};

    await _mapController!.addSource(
        _kRouteSourceId, const GeojsonSourceProperties(data: emptyGeoJson));
    await _mapController!.addLineLayer(
        _kRouteSourceId,
        _kRouteLayerId,
        const LineLayerProperties(
          lineColor: '#2563EB',
          lineWidth: 4.0,
          lineOpacity: 0.9,
          lineCap: "round",
          lineJoin: "round",
        ));

    await _mapController!.addSource(
        _kStopsFijaSourceId, const GeojsonSourceProperties(data: emptyGeoJson));
    await _mapController!.addCircleLayer(
        _kStopsFijaSourceId,
        _kStopsFijaLayerId,
        const CircleLayerProperties(
          circleRadius: 7.0,
          circleColor: '#FFFFFF',
          circleStrokeWidth: 2.5,
          circleStrokeColor: '#2563EB',
        ));

    await _mapController!.addSource(_kStopsInformalSourceId,
        const GeojsonSourceProperties(data: emptyGeoJson));
    await _mapController!.addCircleLayer(
        _kStopsInformalSourceId,
        _kStopsInformalLayerId,
        const CircleLayerProperties(
          circleRadius: 30.0,
          circleColor: '#2563EB',
          circleOpacity: 0.12,
          circleStrokeWidth: 1.5,
          circleStrokeColor: '#2563EB',
          circleStrokeOpacity: 0.3,
        ));

    await _mapController!.addSource(
        _kBusSourceId, const GeojsonSourceProperties(data: emptyGeoJson));

    await _mapController!.addSource(_kUserPinSourceId,
        const GeojsonSourceProperties(data: emptyGeoJson));

    await _mapController!.addSource(_kUserRadiusSourceId,
        const GeojsonSourceProperties(data: emptyGeoJson));

    await _mapController!.addFillLayer(
      _kUserRadiusSourceId,
      _kUserRadiusFillLayerId,
      const FillLayerProperties(
        fillColor: '#00A859',
        fillOpacity: 0.05,
      ),
    );

    await _mapController!.addLineLayer(
      _kUserRadiusSourceId,
      _kUserRadiusLineLayerId,
      const LineLayerProperties(
        lineColor: '#00A859',
        lineWidth: 1.5,
        lineOpacity: 0.28,
      ),
    );

    await _mapController!.addSymbolLayer(
        _kUserPinSourceId,
        _kUserPinLayerId,
        const SymbolLayerProperties(
          iconImage: _kUserPinIconId,
          iconSize: ['interpolate', ['linear'], ['zoom'], 11, 1.0, 15, 1.6],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'bottom',
        ));

    await _mapController!.addCircleLayer(
        _kBusSourceId,
        'bus-selected-halo-layer',
        const CircleLayerProperties(
          circleRadius: 24.0,
          circleColor: '#00A859',
          circleOpacity: 0.45,
          circleBlur: 0.8,
          circleStrokeWidth: 0.0,
        ),
        filter: ['==', ['get', 'isSelected'], true]);

    await _mapController!.addSymbolLayer(
        _kBusSourceId,
        _kBusLayerId,
        const SymbolLayerProperties(
          iconImage: [
            'case',
            ['==', ['get', 'isGhost'], true],
            _kBusGhostIconId,
            _kBusIconId
          ],
          iconSize: [
            'case',
            ['==', ['get', 'isSelected'], true],
            ['interpolate', ['linear'], ['zoom'], 11, 1.5, 15, 2.5],
            ['interpolate', ['linear'], ['zoom'], 11, 1.0, 15, 2.0]
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconRotate: ['get', 'heading'],
          iconRotationAlignment: 'map',
        ));

    _mapController!.onFeatureTapped.add((point, coordinates, id, layerId, annotation) async {
      await _selectBusAtTap(point);
    });
  }

  /// Selecciona el bus cuyo ícono quede dentro de un rect de ±44 px alrededor
  /// del toque. El rect hace que sea fácil tocar un bus aunque el píxel del
  /// ícono sea pequeño (o quede detrás del pin del usuario); si no hay bus,
  /// devuelve false y el toque sigue su curso (p. ej. colocar el pin).
  ///
  /// Deduplicación: el mismo toque dispara feature#onTap Y map#onMapClick casi
  /// en paralelo. Para no hacer doble toggle (seleccionar y deseleccionar al
  /// instante) la primera llamada reclama el toque de forma SÍNCRONA y guarda
  /// el future en vuelo; las llamadas gemelas dentro de 400 ms devuelven el
  /// MISMO future (mismo resultado, un solo toggle).
  Future<bool>? _pendingSelect;
  DateTime? _pendingAt;
  bool _pinMoveHintShown = false;

  Future<bool> _selectBusAtTap(math.Point<double> point) {
    final pending = _pendingSelect;
    if (pending != null &&
        DateTime.now().difference(_pendingAt!) <
            const Duration(milliseconds: 400)) {
      return pending;
    }
    _pendingAt = DateTime.now();
    final future = _doSelectBusAtTap(point);
    _pendingSelect = future;
    return future;
  }

  Future<bool> _doSelectBusAtTap(math.Point<double> point) async {
    // Sin ubicación (GPS negado y sin pin) no hay distancias ni avisos que
    // mostrar: el toque solo sirve para poner el pin.
    if (!ref.read(userLocationProvider).hasPosition) return false;
    try {
      final features = await _mapController!.queryRenderedFeaturesInRect(
        Rect.fromCenter(
          center: Offset(point.x, point.y),
          width: 88,
          height: 88,
        ),
        _kBusHitLayers,
        null,
      );
      if (features.isEmpty) return false;
      final busId = features.first['properties']?['busId'] as String? ?? '';
      if (busId.isEmpty) return false;
      // Selección única: al cambiar de bus se desactivan los avisos del
      // bus anterior; notificaciones y seguimiento son de un bus a la vez.
      ref.read(activeAlertsProvider.notifier).clear();
      ref.read(selectedBusesProvider.notifier).toggleBus(busId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadBusIcons() async {
    if (_mapController == null) return;
    try {
      final activeBytes = await _createFlatTransitMarker(
          const Color(0xFF14274E), isGhost: false);
      final ghostBytes = await _createFlatTransitMarker(
          const Color(0xFF94A3B8), isGhost: true);

      await _mapController!.addImage(_kBusIconId, activeBytes);
      await _mapController!.addImage(_kBusGhostIconId, ghostBytes);
      await _mapController!.addImage(_kUserPinIconId, await _createPinMarker());
    } catch (e) {
      debugPrint("Error generando iconos Flat: $e");
    }
  }

  Future<Uint8List> _createPinMarker() async {
    const size = 80;
    const centerX = size / 2;
    const headCY = 30.0;
    const headR = 26.0;
    const tipY = 76.0;
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Gota con cabeza semicircular perfecta y cola simétrica.
    final dropPath = Path()
      ..moveTo(centerX, tipY)
      ..quadraticBezierTo(centerX - 30, tipY - 28, centerX - headR, headCY)
      ..arcTo(
        Rect.fromCircle(center: const Offset(centerX, headCY), radius: headR),
        math.pi,
        math.pi,
        false,
      )
      ..quadraticBezierTo(centerX + 30, tipY - 28, centerX, tipY);

    canvas.drawShadow(
        dropPath, Colors.black.withValues(alpha: 0.25), 6.0, false);

    // Cuerpo con gradiente (verde claro arriba → esmeralda abajo).
    final dropPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(centerX, 4),
        const Offset(centerX, tipY),
        const [Color(0xFF4ADE80), Color(0xFF059669)],
      );
    canvas.drawPath(dropPath, dropPaint);

    // Brillo "de cristal" en la parte superior.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(centerX, headCY - 16),
        width: 24,
        height: 9,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.20),
    );

    // Aro blanco nítido y punto central con gradiente profundo.
    canvas.drawCircle(const Offset(centerX, headCY), 12.5,
        Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(centerX, headCY),
      8.5,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(centerX - 9, headCY - 9),
          const Offset(centerX + 9, headCY + 9),
          const [Color(0xFF065F46), Color(0xFF00A859)],
        ),
    );
    // Reflejo dentro del punto.
    canvas.drawCircle(
      const Offset(centerX - 2.5, headCY - 3),
      2.2,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List() ?? Uint8List(0);
  }

  Future<Uint8List> _createFlatTransitMarker(Color baseColor,
      {required bool isGhost}) async {
    const size = 80;
    const centerX = size / 2;
    const centerY = size / 2;
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final shadowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: const Offset(centerX, centerY + 2), width: 32, height: 60),
          const Radius.circular(10)));
    canvas.drawShadow(
        shadowPath, Colors.black.withValues(alpha: 0.15), 4.0, false);

    final bodyPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    final bodyRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: const Offset(centerX, centerY), width: 32, height: 60),
        const Radius.circular(10));
    canvas.drawRRect(bodyRect, bodyPaint);

    final glassPaint = Paint()
      ..color = Colors.white.withValues(alpha: isGhost ? 0.5 : 0.95)
      ..style = PaintingStyle.fill;
    final glassRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: const Offset(centerX, centerY - 18), width: 24, height: 10),
        const Radius.circular(4));
    canvas.drawRRect(glassRect, glassPaint);

    // Farolas blancas pequeñas en el FRENTE (arriba): el lado que avanza.
    if (!isGhost) {
      final headlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          const Offset(centerX - 9, centerY - 23), 2.4, headlightPaint);
      canvas.drawCircle(
          const Offset(centerX + 9, centerY - 23), 2.4, headlightPaint);
    }

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List() ?? Uint8List(0);
  }

  Future<void> _applyMapBottomInset(double bottomInset,
      {bool animated = true}) async {
    _currentBottomInset = bottomInset;
    if (_mapController == null || !mounted || kIsWeb) return;

    try {
      await _mapController!.updateContentInsets(
        EdgeInsets.only(bottom: bottomInset),
        animated,
      );
    } catch (_) {}
  }

  void _reloadMapData() {
    if (_mapController == null || widget.routeId == null || !mounted) return;
    // Escucha reactiva (no un read único): si la ruta se seleccionó antes de
    // que el trajectory/paradas se cargaran, se dibuja en cuanto llegan.
    _trajectorySub?.close();
    _stopsSub?.close();
    _trajectorySub = ref.listenManual(
      routeTrajectoryProvider(widget.routeId!),
      (_, next) => next.whenData(_updateRouteSource),
      fireImmediately: true,
    );
    _stopsSub = ref.listenManual(
      busStopsProvider(widget.routeId!),
      (_, next) => next.whenData(_updateStopsSources),
      fireImmediately: true,
    );
  }

  void _updateRouteSource(RouteTrajectory trajectory) {
    if (_mapController == null || !mounted) return;
    _mapController!.setGeoJsonSource(
        _kRouteSourceId, trajectory.toGeoJsonFeatureCollection());

    if (!_hasFitInitialRoute) {
      _fitRouteToVisibleViewport(trajectory, animated: true);
      _hasFitInitialRoute = true;
    }
  }

  void _fitRouteToVisibleViewport(RouteTrajectory trajectory,
      {required bool animated}) {
    if (_mapController == null || trajectory.points.length < 2 || !mounted) {
      return;
    }

    double minLat = trajectory.points.first.lat;
    double maxLat = trajectory.points.first.lat;
    double minLon = trajectory.points.first.lon;
    double maxLon = trajectory.points.first.lon;

    for (final point in trajectory.points) {
      if (point.lat < minLat) minLat = point.lat;
      if (point.lat > maxLat) maxLat = point.lat;
      if (point.lon < minLon) minLon = point.lon;
      if (point.lon > maxLon) maxLon = point.lon;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
    final update = CameraUpdate.newLatLngBounds(
      bounds,
      left: 40,
      top: 148,
      right: 40,
      bottom: _currentBottomInset + 32,
    );

    if (animated) {
      _mapController!.animateCamera(
        update,
        duration: const Duration(milliseconds: 800),
      );
    } else {
      _mapController!.moveCamera(update);
    }
  }

  void _updateStopsSources(List<BusStop> stops) {
    if (_mapController == null || !mounted) return;
    final fijaStops = stops.where((s) => s.tipo == BusStopType.fija).toList();
    final informalStops =
        stops.where((s) => s.tipo == BusStopType.informal).toList();
    _mapController!.setGeoJsonSource(_kStopsFijaSourceId, {
      'type': 'FeatureCollection',
      'features': fijaStops.map((s) => s.toGeoJsonFeature()).toList(),
    });
    _mapController!.setGeoJsonSource(_kStopsInformalSourceId, {
      'type': 'FeatureCollection',
      'features': informalStops.map((s) => s.toGeoJsonFeature()).toList(),
    });
  }

  void _updateBusSourceData(List<BusPosition> positions) {
    if (_mapController == null || !mounted || !_layersReady) return;

    final byId = {for (final p in positions) p.busId: p};
    final now = DateTime.now();

    for (final id in _rawBuses.keys.toList()) {
      if (!byId.containsKey(id)) {
        _rawBuses.remove(id);
        _busMotions.remove(id);
      }
    }

    for (final entry in byId.entries) {
      final id = entry.key;
      final pos = entry.value;
      final prev = _rawBuses[id];
      _rawBuses[id] = pos;

      final needsMotion = !pos.isGhostBus &&
          prev != null &&
          (prev.lat != pos.lat || prev.lon != pos.lon);
      if (!needsMotion) {
        _busMotions.remove(id);
        continue;
      }

      // Tramo nuevo desde la posición actual en pantalla (si hay una
      // animación en curso) para que no haya saltos ni retrocesos.
      final existing = _busMotions[id];
      final from = existing != null && !existing.isFinished(now)
          ? _displayOf(existing, now)
          : (prev.lat, prev.lon, prev.heading);
      _busMotions[id] = _BusMotion(
        fromLat: from.$1,
        fromLon: from.$2,
        fromHeading: from.$3,
        toLat: pos.lat,
        toLon: pos.lon,
        toHeading: pos.heading,
        start: now,
      );
    }

    _ensureBusAnimTicker();
    _pushBusSource();
  }

  /// Interpola linealmente lat/lon y el heading por el arco más corto.
  (double, double, double) _displayOf(_BusMotion motion, DateTime now) {
    final t = (now.difference(motion.start).inMilliseconds /
            _BusMotion.duration.inMilliseconds)
        .clamp(0.0, 1.0);
    double lerp(double a, double b) => a + (b - a) * t;
    var delta = (motion.toHeading - motion.fromHeading) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    final heading = (motion.fromHeading + delta * t + 360) % 360;
    return (lerp(motion.fromLat, motion.toLat),
        lerp(motion.fromLon, motion.toLon), heading);
  }

  /// Ticker de animación (~30 fps): solo corre mientras haya buses moviéndose.
  void _ensureBusAnimTicker() {
    if (_busAnimTimer != null) return;
    _busAnimTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || _mapController == null || !_layersReady) return;
      final now = DateTime.now();
      _busMotions.removeWhere((_, m) => m.isFinished(now));
      _pushBusSource();
      if (_busMotions.isEmpty) {
        _busAnimTimer?.cancel();
        _busAnimTimer = null;
      }
    });
  }

  void _pushBusSource() {
    if (_mapController == null || !mounted || !_layersReady) return;
    final selectedBuses = ref.read(selectedBusesProvider);
    final now = DateTime.now();
    final features = _rawBuses.entries.map((entry) {
      final id = entry.key;
      final pos = entry.value;
      final motion = _busMotions[id];
      final display = motion != null
          ? _displayOf(motion, now)
          : (pos.lat, pos.lon, pos.heading);
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [display.$2, display.$1]
        },
        'properties': {
          'busId': id,
          'heading': display.$3,
          'speedKmh': pos.speedKmh,
          'isGhost': pos.isGhostBus,
          'isSelected': selectedBuses.contains(id),
        },
      };
    }).toList();
    _mapController!.setGeoJsonSource(_kBusSourceId, {
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const ColoredBox(color: AppColors.background);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: MapLibreMap(
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoadedCallback,
            // El mapa nativo silencia map#onMapClick cuando el toque cae sobre un
            // feature (línea de ruta, paradas, pins, buses... dentro de ±10 px) y
            // deja solo feature#onTap. Con este flag, el toque SIEMPRE dispara
            // onMapClick: se coloca el pin en cualquier lado (la selección de bus
            // se decide en _selectBusAtTap).
            featureTapsTriggersMapClick: true,
            // Estilo por URL remota: el mecanismo de asset del plugin
            // (`asset://`) no llega a cargar y deja el mapa en blanco.
            // MapLibre cachea el estilo y los tiles; el placeholder cubre
            // el breve primer pintado.
            styleString:
                'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
            initialCameraPosition: const CameraPosition(
              target: LatLng(11.0041, -74.8070),
              zoom: 11.0,
            ),
            compassEnabled: false,
            myLocationEnabled: false,
            onMapClick: (point, latLng) async {
              // El mapa aún no está listo (estilo/fuentes cargando): no se
              // pueden colocar pins ni seleccionar buses sobre un mapa que
              // todavía no pinta. El placeholder además bloquea el toque.
              if (!_layersReady) return;
              // Un bus cerca del toque (aunque quede debajo/encima del pin) se
              // selecciona y NO se mueve el pin manual.
              if (await _selectBusAtTap(point)) return;
              if (!mounted) return;
              final location = ref.read(userLocationProvider);
              // Con el GPS activo el pin sigue al usuario: el toque no lo mueve.
              // Durante la búsqueda de GPS el toque sí coloca el pin manual
              // (cancela la espera de localización).
              if (location.mode == UserLocationMode.gps) {
                return;
              }
              // Pin fijo: una vez puesto no se mueve con toques (evita moverlo por
              // accidente al tocar el mapa); se quita con "Quitar" y se vuelve a
              // tocar donde se quiera poner.
              if (location.mode == UserLocationMode.manual) {
                if (!_pinMoveHintShown && context.mounted) {
                  _pinMoveHintShown = true;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Tu pin está fijo: quítalo y vuelve a tocar para moverlo'),
                  ));
                }
                return;
              }
              ref
                  .read(userLocationProvider.notifier)
                  .setManualPin(latLng.latitude, latLng.longitude);
            },
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: false,
            zoomGesturesEnabled: true,
            minMaxZoomPreference: const MinMaxZoomPreference(5.0, 18.5),
            cameraTargetBounds: CameraTargetBounds(_colombiaBounds),
          ),
        ),
        _buildStylePlaceholder(),
      ],
    );
  }

  /// Placeholder calmado mientras el estilo y las fuentes del mapa cargan:
  /// evita el "fondo en blanco, ¿se colgó?" en el primer pintado. Se funde
  /// con el mapa cuando las capas están listas y se quita del árbol.
  Widget _buildStylePlaceholder() {
    final visible = !_layersReady && _placeholderShown;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      onEnd: () {
        if (!visible && _placeholderShown) setState(() => _placeholderShown = false);
      },
      child: _placeholderShown
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: const ColoredBox(
                color: AppColors.background,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_bus_rounded,
                        size: 44,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Preparando tu mapa…',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
