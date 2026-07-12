import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

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
  static const _kBusIconPngBase64 =
      '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';
  static const _kBusGhostIconPngBase64 =
      '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';

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
          iconSize: 1.2,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconRotate: ['get', 'heading'],
          iconRotationAlignment: 'map',
        ));
  }

  Future<void> _loadBusIcons() async {
    if (_mapController == null) return;
    try {
      await _mapController!
          .addImage(_kBusIconId, base64Decode(_kBusIconPngBase64));
      await _mapController!
          .addImage(_kBusGhostIconId, base64Decode(_kBusGhostIconPngBase64));
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
