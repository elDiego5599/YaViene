import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../providers/map_view_state.dart';
import '../providers/tracking_providers.dart'
    show
        NearbyBuses,
        nearbyBusesProvider,
        selectedBusesProvider;
import '../providers/user_location_provider.dart';

class MapWidget extends ConsumerStatefulWidget {
  final String? routeId;
  const MapWidget({super.key, this.routeId});

  @override
  ConsumerState<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidget>
    with WidgetsBindingObserver {
  MapLibreMapController? _mapController;
  ProviderSubscription<NearbyBuses>? _movingBusSubscription;
  ProviderSubscription<UserLocationState>? _userPinSubscription;
  ProviderSubscription<double>? _mapInsetSubscription;
  RouteTrajectory? _lastTrajectory;
  double _currentBottomInset = 0;
  bool _layersReady = false;
  bool _hasFitInitialRoute = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  static const _kRouteSourceId = 'route-source';
  static const _kRouteLayerId = 'route-line';
  static const _kStopsFijaSourceId = 'stops-fija-source';
  static const _kStopsFijaLayerId = 'stops-fija-layer';
  static const _kStopsInformalSourceId = 'stops-informal-source';
  static const _kStopsInformalLayerId = 'stops-informal-layer';
  static const _kBusSourceId = 'bus-source';
  static const _kBusLayerId = 'bus-layer';
  static const _kBusIconId = 'bus-icon-active';
  static const _kBusGhostIconId = 'bus-icon-ghost';
  static const _kBusFarIconId = 'bus-icon-far';
  static const _kUserPinSourceId = 'user-pin-source';
  static const _kUserPinLayerId = 'user-pin-layer';
  static const _kUserPinIconId = 'user-pin-icon';

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _movingBusSubscription?.close();
    _userPinSubscription?.close();
    _mapInsetSubscription?.close();
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
    _movingBusSubscription =
        ref.listenManual(nearbyBusesProvider(routeId), (previous, next) {
      if (!mounted) return;
      if (_lifecycleState != AppLifecycleState.resumed) return;
      _updateBusSourceData(next);
    }, fireImmediately: true);
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
    if (state.isManual && state.hasPosition) {
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
    } else {
      _mapController!
          .setGeoJsonSource(_kUserPinSourceId,
              const {'type': 'FeatureCollection', 'features': []});
    }
  }

  void _teardownBusSubscription() {
    _movingBusSubscription?.close();
    _movingBusSubscription = null;
    if (_mapController != null && mounted) {
      const emptyGeoJson = {"type": "FeatureCollection", "features": []};
      _mapController!.setGeoJsonSource(_kBusSourceId, emptyGeoJson);
    }
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
      }
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;
  }

  Future<void> _onStyleLoadedCallback() async {
    if (!mounted) return;
    try {
      await _loadBusIcons();
      await _initializeMapSources();
      _layersReady = true;
      await _applyMapBottomInset(ref.read(mapBottomInsetProvider),
          animated: false);
      _setupUserPinSubscription();
      if (widget.routeId != null) {
        await _reloadMapData();
        _setupBusSubscription(widget.routeId!);
      }
    } catch (e) {
      debugPrint('MapWidget._onStyleLoadedCallback error: $e');
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
            ['==', ['get', 'isFar'], true],
            _kBusFarIconId,
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
      final features = await _mapController!
          .queryRenderedFeatures(point, [_kBusLayerId], null);
      if (features.isNotEmpty) {
        final busId = features.first['properties']['busId'] as String;
        final success =
            ref.read(selectedBusesProvider.notifier).toggleBus(busId);

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Solo puedes seguir hasta 2 buses a la vez.",
                style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Color(0xFF14274E),
          ));
        }
      }
    });
  }

  Future<void> _loadBusIcons() async {
    if (_mapController == null) return;
    try {
      final activeBytes = await _createFlatTransitMarker(
          const Color(0xFF14274E), isGhost: false);
      final ghostBytes = await _createFlatTransitMarker(
          const Color(0xFF94A3B8), isGhost: true);
      final farBytes = await _createFlatTransitMarker(
          const Color(0xFFA8B3C4), isGhost: true);

      await _mapController!.addImage(_kBusIconId, activeBytes);
      await _mapController!.addImage(_kBusGhostIconId, ghostBytes);
      await _mapController!.addImage(_kBusFarIconId, farBytes);
      await _mapController!.addImage(_kUserPinIconId, await _createPinMarker());
    } catch (e) {
      debugPrint("Error generando iconos Flat: $e");
    }
  }

  Future<Uint8List> _createPinMarker() async {
    const size = 80;
    const centerX = size / 2;
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final dropPath = Path()
      ..moveTo(centerX, size - 10)
      ..cubicTo(centerX - 26, size - 34, 12, size - 48, 12, size - 58)
      ..arcToPoint(const Offset(centerX - 12, 18),
          radius: const Radius.circular(30))
      ..arcToPoint(const Offset(size - 12, size - 58),
          radius: const Radius.circular(30))
      ..close();

    canvas.drawShadow(dropPath, Colors.black.withValues(alpha: 0.2), 3.0, false);
    final dropPaint = Paint()
      ..color = const Color(0xFF00A859)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dropPath, dropPaint);

    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(centerX, size - 52), 10, whitePaint);
    canvas.drawCircle(
        const Offset(centerX, size - 52), 6, Paint()..color = const Color(0xFF14274E));

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
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

    if (!isGhost) {
      final lightPaint = Paint()
        ..color = const Color(0xFF00A859)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(centerX - 8, centerY + 24), 3, lightPaint);
      canvas.drawCircle(const Offset(centerX + 8, centerY + 24), 3, lightPaint);
    }

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
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
      final trajectory = _lastTrajectory;
      if (trajectory != null) {
        _fitRouteToVisibleViewport(trajectory, animated: animated);
      }
    } catch (_) {}
  }

  Future<void> _reloadMapData() async {
    if (_mapController == null || widget.routeId == null || !mounted) return;
    final trajectoryAsync = ref.read(routeTrajectoryProvider(widget.routeId!));
    final stopsAsync = ref.read(busStopsProvider(widget.routeId!));

    trajectoryAsync.whenData((trajectory) => _updateRouteSource(trajectory));
    stopsAsync.whenData((stops) => _updateStopsSources(stops));
  }

  void _updateRouteSource(RouteTrajectory trajectory) {
    if (_mapController == null || !mounted) return;
    _lastTrajectory = trajectory;
    _mapController!.setGeoJsonSource(
        _kRouteSourceId, trajectory.toGeoJsonFeatureCollection());

    if (!_hasFitInitialRoute) {
      _fitRouteToVisibleViewport(trajectory, animated: true);
      _hasFitInitialRoute = true;
    }
  }

  void _fitRouteToVisibleViewport(RouteTrajectory trajectory,
      {required bool animated}) {
    if (_mapController == null || trajectory.points.isEmpty || !mounted) return;

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

  void _updateBusSourceData(NearbyBuses buses) {
    if (_mapController == null || !mounted || !_layersReady) return;
    final selectedBuses = ref.read(selectedBusesProvider);
    Map<String, dynamic> busFeature(BusPosition pos, {required bool isFar}) {
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [pos.lon, pos.lat]
        },
        'properties': {
          'busId': pos.busId,
          'heading': pos.heading,
          'speedKmh': pos.speedKmh,
          'isGhost': pos.isGhostBus,
          'isFar': isFar,
          'isSelected': selectedBuses.contains(pos.busId),
        },
      };
    }

    _mapController!.setGeoJsonSource(_kBusSourceId, {
      'type': 'FeatureCollection',
      'features': [
        ...buses.nearby.map((pos) => busFeature(pos, isFar: false)),
        ...buses.far.map((pos) => busFeature(pos, isFar: true)),
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const ColoredBox(color: AppColors.background);
    }

    return MapLibreMap(
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoadedCallback,
      styleString:
          'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
      initialCameraPosition: const CameraPosition(
        target: LatLng(11.0041, -74.8070),
        zoom: 11.0,
      ),
      compassEnabled: false,
      myLocationEnabled: false,
      onMapClick: (point, latLng) {
        final location = ref.read(userLocationProvider);
        if (location.mode == UserLocationMode.gps ||
            location.mode == UserLocationMode.locating) {
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
    );
  }
}
