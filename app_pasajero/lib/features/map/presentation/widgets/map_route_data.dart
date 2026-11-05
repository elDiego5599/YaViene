part of 'map_widget.dart';

// Datos de la ruta: trayectoria y paradas. Antes vivían mezclados en
// map_widget.dart; ahora tienen su propio archivo para que el mapa no sea
// un cajón con todo.

extension _MapRouteData on _MapWidgetState {
  void reloadMapData() {
    if (_mapController == null || widget.routeId == null || !mounted) return;
    _trajectorySub?.close();
    _stopsSub?.close();
    _seguidorSub?.close();
    // La caminada al punto de espera se mide con la ruta: llega después del
    // pin, y cambia con ella.
    _seguidorSub = ref.listenManual(
      seguidorRutaProvider(widget.routeId!),
      (_, __) => _renderCaminadaDelPin(),
      fireImmediately: true,
    );
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
  bool centerOnUserPin({required bool animated, bool pedidoExplicito = false}) {
    if (_mapController == null || !mounted) return false;
    final ubicacion = ref.read(userLocationProvider);
    final lat = ubicacion.lat;
    final lon = ubicacion.lon;
    if (lat == null || lon == null) return false;
    moveCameraToBounds(
      waitingPointBounds(lat, lon),
      animated: animated,
      pedidoExplicito: pedidoExplicito,
    );
    return true;
  }

  /// Con el pin ya encuadrado, lo abre hasta el bus más cercano si ninguno
  /// cae cerca: sin esto, una ruta que no pasa por el pin dejaba el mapa sin
  /// buses a la vista (AUD29-04). Si el usuario ya movió el mapa,
  /// `moveCameraToBounds` no lo pisa.
  void openToNearestBus() {
    final ubicacion = ref.read(userLocationProvider);
    final lat = ubicacion.lat;
    final lon = ubicacion.lon;
    if (lat == null || lon == null) return;
    final caja = esperaConBusMasCercano((
      lat: lat,
      lon: lon
    ), [
      for (final bus in _rawBuses.values) (lat: bus.lat, lon: bus.lon),
    ]);
    if (caja != null) {
      moveCameraToBounds(caja, animated: true, bajoLaPildora: true);
    }
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

  void moveCameraToBounds(
    FitBounds caja, {
    required bool animated,
    bool pedidoExplicito = false,
    bool bajoLaPildora = false,
  }) {
    if (!_decisionCamara.permiteEncuadreAutomatico && !pedidoExplicito) {
      return;
    }
    // Espera a que el mapa termine de aplicar el margen de la hoja: los
    // rellenos de abajo se calculan contando con él.
    _margenEnCurso.then((_) {
      // El pin/ruta pudo encolarse antes de que llegara el toque al aviso.
      // Revalidar aquí impide que su Future tardío pise el viaje al bus.
      if (_mapController == null ||
          !mounted ||
          (!_decisionCamara.permiteEncuadreAutomatico && !pedidoExplicito)) {
        return;
      }
      _moverCamaraA(caja, animated: animated, bajoLaPildora: bajoLaPildora);
    });
  }

  void _moverCamaraA(
    FitBounds caja, {
    required bool animated,
    bool bajoLaPildora = false,
  }) {
    final relleno = rellenoDelEncuadre(
      hoja: _currentBottomInset,
      ios: defaultTargetPlatform == TargetPlatform.iOS,
      bajoLaPildora: bajoLaPildora,
      foco: ref.read(mapGuideFocusProvider),
      alto: context.size?.height,
    );
    final update = CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(caja.minLat, caja.minLon),
        northeast: LatLng(caja.maxLat, caja.maxLon),
      ),
      left: relleno.left,
      top: relleno.top,
      right: relleno.right,
      bottom: relleno.bottom,
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

  /// Pinta la caminada de [lat], [lon] al punto de espera de la ruta que se
  /// sigue (ver `caminadaHastaLaRuta`). Se llama también en el arrastre:
  /// la línea va con el dedo.
  void _renderCaminada(double lat, double lon) {
    if (_mapController == null || !mounted) return;
    final ruta = _seguidorSub?.read()?.ruta;
    _mapController!.setGeoJsonSource(_MapWidgetState._kCaminadaSourceId,
        caminadaHastaLaRuta(ruta, lat, lon));
  }

  /// La caminada del pin guardado, para cuando llega o cambia la ruta. En el
  /// arrastre la pinta el gesto, con el pin donde está el dedo.
  void _renderCaminadaDelPin() {
    if (!_layersReady || _pinDragging) return;
    final ubicacion = ref.read(userLocationProvider);
    if (ubicacion.lat == null || ubicacion.lon == null) return;
    _renderCaminada(ubicacion.lat!, ubicacion.lon!);
  }

  void teardownRouteData() {
    _trajectorySub?.close();
    _trajectorySub = null;
    _seguidorSub?.close();
    _seguidorSub = null;
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
    _mapController!
        .setGeoJsonSource(_MapWidgetState._kCaminadaSourceId, emptyGeoJson);
  }
}

/// Los rellenos del encuadre: dejan lo encuadrado en el hueco libre entre la
/// barra de búsqueda y la hoja (centrado en la pantalla entera, el pin se
/// habría quedado debajo de la tarjeta). Con la guía enseñando el mapa
/// ([foco], en coordenadas de pantalla, y el mapa la ocupa entera), en el
/// trozo que ella deja a la vista.
///
/// En iOS el mapa suma su margen de contenido ([hoja], lo que tapa) al
/// relleno de abajo; en Android el relleno lo sustituye. Sin restarlo, en
/// iPhone la hoja contaba dos veces y el pin quedaba alto: así salía el
/// botón de tu pin (dueño, 2026-10-16).
///
/// [bajoLaPildora] es para cajas cuyo borde de arriba importa, como la del
/// pin con el bus más cercano: ahí lo de arriba es un bus y no puede quedar
/// debajo de la píldora de tu punto.
EdgeInsets rellenoDelEncuadre({
  required double hoja,
  required bool ios,
  Rect? foco,
  double? alto,
  bool bajoLaPildora = false,
}) {
  final yaDescontado = ios ? hoja : 0.0;
  if (foco != null && alto != null) {
    return EdgeInsets.fromLTRB(
        40, foco.top, 40, math.max(0.0, alto - foco.bottom - yaDescontado));
  }
  return EdgeInsets.fromLTRB(
    40,
    bajoLaPildora ? rellenoBajoLaPildora : 148,
    40,
    hoja + 32 - yaDescontado,
  );
}

/// El borde de arriba que deja libre la píldora de tu punto: en el iPhone 17
/// termina en y≈205 pt (barra de 133 y píldora de dos líneas debajo), más
/// 24 pt de aire para que el bus no la roce.
const double rellenoBajoLaPildora = 229;
