part of 'map_widget.dart';

// Datos de la ruta: trayectoria y paradas. Antes vivían mezclados en
// map_widget.dart; ahora tienen su propio archivo para que el mapa no sea
// un cajón con todo.

extension _MapRouteData on _MapWidgetState {
  void reloadMapData() {
    if (_mapController == null || widget.routeId == null || !mounted) return;
    _trajectorySub?.close();
    _stopsSub?.close();
    _trajectorySub = ref.listenManual(
      routeTrajectoryProvider(widget.routeId!),
      (_, next) => next.whenData(updateRouteSource),
      fireImmediately: true,
    );
    _stopsSub = ref.listenManual(
      busStopsProvider(widget.routeId!),
      (_, next) => next.whenData(updateStopsSources),
      fireImmediately: true,
    );
  }

  void updateRouteSource(RouteTrajectory trajectory) {
    if (_mapController == null || !mounted) return;
    _mapController!.setGeoJsonSource(_MapWidgetState._kRouteSourceId,
        trajectory.toGeoJsonFeatureCollection());

    if (!_hasFitInitialRoute) {
      fitRouteToVisibleViewport(trajectory, animated: true);
      _hasFitInitialRoute = true;
    }
  }

  void fitRouteToVisibleViewport(RouteTrajectory trajectory,
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

  void updateStopsSources(List<BusStop> stops) {
    if (_mapController == null || !mounted) return;
    final fijaStops = stops.where((s) => s.tipo == BusStopType.fija).toList();
    final informalStops =
        stops.where((s) => s.tipo == BusStopType.informal).toList();
    _mapController!.setGeoJsonSource(_MapWidgetState._kStopsFijaSourceId, {
      'type': 'FeatureCollection',
      'features': fijaStops.map((s) => s.toGeoJsonFeature()).toList(),
    });
    _mapController!.setGeoJsonSource(_MapWidgetState._kStopsInformalSourceId, {
      'type': 'FeatureCollection',
      'features': informalStops.map((s) => s.toGeoJsonFeature()).toList(),
    });
  }

  void teardownRouteData() {
    _trajectorySub?.close();
    _trajectorySub = null;
    _stopsSub?.close();
    _stopsSub = null;
    if (_mapController == null || !mounted) return;
    const emptyGeoJson = {"type": "FeatureCollection", "features": []};
    _mapController!
        .setGeoJsonSource(_MapWidgetState._kRouteSourceId, emptyGeoJson);
    _mapController!
        .setGeoJsonSource(_MapWidgetState._kStopsFijaSourceId, emptyGeoJson);
    _mapController!.setGeoJsonSource(
        _MapWidgetState._kStopsInformalSourceId, emptyGeoJson);
  }
}
