import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../utils/marker_generator.dart';

class MapWidget extends ConsumerStatefulWidget {
  final String? routeId;
  const MapWidget({super.key, this.routeId});

  @override
  ConsumerState<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidget>
    with WidgetsBindingObserver {
  MapLibreMapController? _mapController;
  ProviderSubscription<AsyncValue<BusPosition>>? _movingBusSubscription;
  bool _layersReady = false;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _movingBusSubscription?.close();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeId != widget.routeId && _layersReady) {
      _reloadMapData();
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
      if (widget.routeId != null) await _reloadMapData();
      _movingBusSubscription ??=
          ref.listenManual(movingBusProvider, (previous, next) {
        if (!mounted) return;
        if (_lifecycleState != AppLifecycleState.resumed) return;
        next.whenData(_updateBusSourceData);
      });
    } catch (_) {}
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
    await _mapController!.addSymbolLayer(
        _kBusSourceId,
        _kBusLayerId,
        const SymbolLayerProperties(
          iconImage: [
            'case',
            [
              '==',
              ['get', 'isGhost'],
              true
            ],
            _kBusGhostIconId,
            _kBusIconId
          ],
          iconSize: 1.6,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconRotate: ['get', 'heading'],
          iconRotationAlignment: 'map',
        ));
  }

  Future<void> _loadBusIcons() async {
    try {
      final activeBytes = await MarkerGenerator.generateBusMarker(isGhost: false);
      final ghostBytes = await MarkerGenerator.generateBusMarker(isGhost: true);
      await _mapController!.addImage(_kBusIconId, activeBytes);
      await _mapController!.addImage(_kBusGhostIconId, ghostBytes);
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
    _mapController!.setGeoJsonSource(
        _kRouteSourceId, trajectory.toGeoJsonFeatureCollection());
    final center = trajectory.center;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(center.lat, center.lon), zoom: 12.5)),
      duration: const Duration(milliseconds: 800),
    );
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

  void _updateBusSourceData(BusPosition position) {
    if (_mapController == null || !mounted) return;
    _mapController!.setGeoJsonSource(_kBusSourceId, {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [position.lon, position.lat]
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
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: false,
      zoomGesturesEnabled: true,
    );
  }
}
