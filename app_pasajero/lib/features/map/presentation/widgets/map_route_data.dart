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
  }

  /// Lleva la cámara al punto de espera del usuario y devuelve si lo hizo.
  ///
  /// Es el encuadre que manda cuando hay pin (o GPS). La app mide desde ese
  /// punto y el usuario lo puso él: al abrir los buses en vivo lo que tiene
  /// que ver es su sitio, no un plano general de la ruta con el pin perdido
  /// en una esquina.
  bool centerOnUserPin({required bool animated}) {
    if (_mapController == null || !mounted) return false;
    final ubicacion = ref.read(userLocationProvider);
    final lat = ubicacion.lat;
    final lon = ubicacion.lon;
    if (lat == null || lon == null) return false;
    moveCameraToBounds(waitingPointBounds(lat, lon), animated: animated);
    return true;
  }

  /// Encuadra lo que está vivo: el punto de espera si existe y, si no, los
  /// buses de la ruta.
  ///
  /// La caja la calculan `waitingPointBounds` y `liveViewportBounds`; aquí
  /// solo se elige cuál y se le pasa a la cámara.
  void fitLiveViewport({required bool animated}) {
    if (_mapController == null || !mounted) return;
    if (centerOnUserPin(animated: animated)) return;

    final caja = liveViewportBounds([
      for (final bus in _rawBuses.values) (lat: bus.lat, lon: bus.lon),
    ]);
    // Sin nada que enmarcar es mejor no mover la cámara: el usuario la dejó
    // donde tocó para poner su pin, y un salto a ninguna parte es peor que
    // quedarse quieto.
    if (caja == null) return;
    moveCameraToBounds(caja, animated: animated);
  }

  void moveCameraToBounds(FitBounds caja, {required bool animated}) {
    // Espera a que el mapa termine de aplicar el margen de la hoja: los
    // rellenos de abajo se calculan contando con él.
    _margenEnCurso.then((_) {
      if (_mapController == null || !mounted) return;
      _moverCamaraA(caja, animated: animated);
    });
  }

  void _moverCamaraA(FitBounds caja, {required bool animated}) {
    // Con la guía enseñando el mapa, el encuadre va al trozo que ella deja
    // a la vista. La caja llega en coordenadas de pantalla y el mapa ocupa
    // la pantalla entera, así que sus bordes son los rellenos tal cual.
    final foco = ref.read(mapGuideFocusProvider);
    final alto = context.size?.height;
    final enFoco = foco != null && alto != null;
    // En iOS el mapa suma su margen de contenido (el alto de la hoja) al
    // relleno que se le pasa aquí; en Android el relleno lo sustituye. Sin
    // restarlo, en iPhone la hoja contaba dos veces y el pin quedaba en la
    // parte alta del trozo iluminado en vez de en su centro.
    final yaDescontado =
        defaultTargetPlatform == TargetPlatform.iOS ? _currentBottomInset : 0.0;
    final update = CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(caja.minLat, caja.minLon),
        northeast: LatLng(caja.maxLat, caja.maxLon),
      ),
      // Los rellenos dejan el encuadre en el hueco que queda libre entre la
      // barra de búsqueda y la hoja: centrado en la pantalla entera, el pin
      // se habría quedado debajo de la tarjeta.
      left: 40,
      top: enFoco ? foco.top : 148,
      right: 40,
      bottom: enFoco
          ? math.max(0.0, alto - foco.bottom - yaDescontado)
          : _currentBottomInset + 32,
    );

    // Movimiento reducido: 800 ms de ciudad desplazándose es exactamente el
    // movimiento de campo grande que esa preferencia existe para quitar. Con
    // ella activada la cámara aparece ya puesta, sin viaje.
    if (animated && !AppMotion.reducido(context)) {
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
