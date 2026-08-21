import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../providers/map_tour_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/tracking_providers.dart'
    show busPositionsSourceProvider, nearbyRadiusMeters, selectedBusesProvider;
import '../providers/user_location_provider.dart';
import '../utils/bus_hit_test.dart';
import 'map_bus_animator.dart';
import 'map_markers.dart' show loadBusIcons;

class MapWidget extends ConsumerStatefulWidget {
  final String? routeId;
  final ValueChanged<Rect?>? onGuideBusTargetChanged;

  const MapWidget({
    super.key,
    this.routeId,
    this.onGuideBusTargetChanged,
  });

  @override
  ConsumerState<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidget>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  MapLibreMapController? _mapController;
  ProviderSubscription<AsyncValue<List<BusPosition>>>? _movingBusSubscription;
  ProviderSubscription<UserLocationState>? _userPinSubscription;
  ProviderSubscription<double>? _mapInsetSubscription;
  ProviderSubscription<int>? _cameraRequestSubscription;
  ProviderSubscription<Set<String>>? _busSelectionSubscription;
  ProviderSubscription<AsyncValue<RouteTrajectory>>? _trajectorySub;
  ProviderSubscription<AsyncValue<List<BusStop>>>? _stopsSub;
  double _currentBottomInset = 0;
  bool _layersReady = false;
  bool _styleFailed = false;
  int _mapGeneration = 0;
  bool _styleInitInFlight = false;
  bool _hasFitInitialRoute = false;
  bool _placeholderShown = true;
  Timer? _placeholderTimeout;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  /// Pulso "radar" bajo el pin del usuario: la animación corre en Flutter y
  /// solo se re-proyecta la posición del pin cuando cambia la cámara.
  /// Se inicializa en initState: un `late final` perezoso se crearía por
  /// primera vez dentro de dispose() (TickerMode lookup sobre un elemento
  /// ya desmontado) y explotaría al desmontar el mapa.
  late final AnimationController _haloCtrl;

  /// Posición en pantalla del punto del pin (punta de la gota), para pintar
  /// el pulso encima del mapa nativo. null mientras no haya posición.
  Offset? _pinScreenPos;
  BusPosition? _guideBusPosition;

  /// La imagen del pin mide 80 px y su punta está en y=76 con ancla al centro
  /// (40,40): el punto geográfico queda 36 px debajo del centro del icono.
  static const double _pinTipOffset = 36.0;

  /// El pin está siendo arrastrado: el mapa pinta el pin en la posición del
  /// dedo y las actualizaciones del GPS no deben re-pintarlo (salto visible).
  bool _pinDragging = false;

  /// Última posición cruda recibida por bus (para propiedades del ícono).
  final Map<String, BusPosition> _rawBuses = {};

  /// Tramo de animación en curso por bus (interpolación entre fixes).
  final Map<String, BusMotion> _busMotions = {};
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

  /// Id del feature GeoJSON del pin. La plataforma nativa lo reporta en los
  /// eventos de arrastre (`feature#onDrag`) para filtrar que el gesto sea del
  /// pin del usuario y no de otra capa.
  static const _kUserPinFeatureId = 'user-pin-feature';
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
    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    WidgetsBinding.instance.addObserver(this);
    _mapInsetSubscription =
        ref.listenManual<double>(mapBottomInsetProvider, (previous, next) {
      _applyMapBottomInset(next);
    });
    _cameraRequestSubscription =
        ref.listenManual<int>(mapCameraRequestProvider, (previous, next) {
      if (previous == next) return;
      _moveToRequestedCamera();
    });
    // Selección de bus (desde la hoja): el mapa debe repintar el halo y el
    // tamaño del ícono al instante, sin esperar el siguiente paquete GPS.
    _busSelectionSubscription =
        ref.listenManual<Set<String>>(selectedBusesProvider, (previous, next) {
      if (!mounted || !_layersReady) return;
      _pushBusSource();
    });
    // Red de seguridad: si el estilo no llega a cargar (p. ej. red lenta o
    // un fallo de MapLibre), el placeholder nunca debe quedarse para
    // siempre. Pasado el límite se funde y deja ver el mapa (o el fondo).
    _scheduleStyleTimeout();
  }

  /// Programa (o reprograma) el timeout del estilo: si pasan 7 s sin que las
  /// capas estén listas, el placeholder se funde y se ofrece "Reintentar".
  /// Se vuelve a llamar en cada reintento: un segundo fallo debe mostrar el
  /// banner otra vez, no quedarse en "Preparando tu mapa…" para siempre.
  void _scheduleStyleTimeout() {
    _placeholderTimeout?.cancel();
    _placeholderTimeout = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      if (!_layersReady && _placeholderShown) {
        setState(() {
          _placeholderShown = false;
          // El estilo no llegó: sin feedback el mapa queda inerte. Se marca
          // el fallo para ofrecer "Reintentar" en vez de una pantalla muda.
          _styleFailed = true;
        });
      }
    });
  }

  /// Recrea el mapa desde cero (cambio de key) para reintentar cargar el
  /// estilo tras un fallo de red/CDN.
  void _retryMap() {
    if (!mounted) return;
    setState(() {
      _mapGeneration++;
      _styleFailed = false;
      _layersReady = false;
      _styleInitInFlight = false;
      _placeholderShown = true;
    });
    // Nuevo intento: hay que reprogramar el timeout, o un segundo fallo se
    // quedaría en "Preparando tu mapa…" sin banner (BUG-04).
    _scheduleStyleTimeout();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _haloCtrl.dispose();
    _placeholderTimeout?.cancel();
    _movingBusSubscription?.close();
    _userPinSubscription?.close();
    _mapInsetSubscription?.close();
    _cameraRequestSubscription?.close();
    _busSelectionSubscription?.close();
    _trajectorySub?.close();
    _stopsSub?.close();
    _busAnimTimer?.cancel();
    _busAnimTimer = null;
    // El plugin ya desecha el controller al desmontar el MapView; volver a
    // llamar dispose() sobre uno desechado lanza una excepción.
    if (_mapController != null && !_mapController!.isDisposed) {
      _mapController!.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    ref.read(appLifecycleProvider.notifier).state = state;
    if (state == AppLifecycleState.resumed) {
      // Un arrastre no sobrevive al fondo: si quedó a medias, el pin vuelve
      // a obedecer al GPS.
      _pinDragging = false;
      unawaited(ref.read(userLocationProvider.notifier).resumeGpsIfNeeded());
      // En background se descartaron posiciones (el listener está gateado);
      // al volver se reaplica el último valor del provider, o el mapa se
      // quedaría congelado hasta el próximo paquete del socket (BUG-05).
      _reapplyLastPositions();
    }
  }

  /// Reaplica al mapa las últimas posiciones conocidas de la ruta activa.
  void _reapplyLastPositions() {
    final routeId = widget.routeId;
    if (routeId == null || !mounted || !_layersReady) return;
    final positions = ref.read(busPositionsSourceProvider(routeId)).value;
    if (positions != null) _updateBusSourceData(positions);
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
    _guideBusPosition = null;
    widget.onGuideBusTargetChanged?.call(null);
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
      // Durante el arrastre el pin sigue al dedo: un fix del GPS en el medio
      // del gesto no debe saltarlo de vuelta a la posición del GPS.
      if (_pinDragging && state.mode == UserLocationMode.gps) return;
      _renderPin(state.lat!, state.lon!);
      unawaited(_refreshPinScreenPos());
      return;
    }
    _mapController!.setGeoJsonSource(_kUserPinSourceId, emptyGeoJson);
    _mapController!.setGeoJsonSource(_kUserRadiusSourceId, emptyGeoJson);
    if (_pinScreenPos != null && mounted) {
      setState(() => _pinScreenPos = null);
    }
  }

  /// Proyecta la posición del usuario a coordenadas de pantalla para anclar
  /// el pulso "radar" sobre el mapa nativo. La proyección es barata: solo se
  /// llama cuando cambia el estado de ubicación o la cámara se detiene, no en
  /// cada frame de la animación.
  Future<void> _refreshPinScreenPos() async {
    if (!_layersReady || _mapController == null || !mounted) return;
    final loc = ref.read(userLocationProvider);
    if (!loc.hasPosition) return;
    try {
      final projected =
          await _mapController!.toScreenLocation(LatLng(loc.lat!, loc.lon!));
      if (!mounted) return;
      setState(() => _pinScreenPos = Offset(
          projected.x.toDouble(), projected.y.toDouble() + _pinTipOffset));
    } catch (_) {
      // El mapa aún no tiene cámara lista o la proyección falló: el pulso se
      // reintentará en el próximo evento (cámara idle / cambio de ubicación).
    }
  }

  /// Pinta el pin y su radio "cerca de ti" en [lat], [lon]. Se usa tanto para
  /// reflejar el estado (GPS o manual) como durante el arrastre del pin, para
  /// que siga al dedo en tiempo real sin esperar al fin del gesto.
  void _renderPin(double lat, double lon) {
    if (_mapController == null || !mounted) return;
    _mapController!.setGeoJsonSource(_kUserRadiusSourceId, {
      'type': 'FeatureCollection',
      'features': [
        _radiusCircleFeature(lat, lon, nearbyRadiusMeters.toDouble()),
      ],
    });
    // 'draggable': true es lo que la plataforma nativa consulta para decidir
    // si el gesto de mover el dedo sobre el pin lo ARRASTRA en vez de hacer
    // paneo del mapa (MapLibreMapController.startDragging).
    _mapController!.setGeoJsonSource(_kUserPinSourceId, {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'id': _kUserPinFeatureId,
          'geometry': {
            'type': 'Point',
            'coordinates': [lon, lat]
          },
          'properties': const {'draggable': true},
        },
      ],
    });
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
      'geometry': {
        'type': 'Polygon',
        'coordinates': [coordinates]
      },
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
    // La vista nativa se recreó (p. ej. al volver de segundo plano bajo
    // presión de memoria, o con "Don't keep activities"): capas y handlers
    // quedaron en la vista vieja; hay que volver a montarlos en el próximo
    // onStyleLoaded en lugar de saltarlo por el guard de _layersReady.
    if (_mapController != null && _mapController != controller) {
      _layersReady = false;
      _styleInitInFlight = false;
      _hasFitInitialRoute = false;
    }
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
      // Si el estilo cargó tarde (tras el timeout), se quita el banner de error.
      if (_styleFailed) _styleFailed = false;
      // CRÍTICO: el placeholder se construye según `_layersReady`; sin un
      // rebuild aquí se quedaría en "Preparando tu mapa…" aunque el estilo
      // ya haya cargado.
      if (mounted) setState(() {});
      await _applyMapBottomInset(ref.read(mapBottomInsetProvider),
          animated: false);
      _moveToRequestedCamera();
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

    await _mapController!.addSource(
        _kUserPinSourceId, const GeojsonSourceProperties(data: emptyGeoJson));

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
          iconSize: [
            'interpolate',
            ['linear'],
            ['zoom'],
            11,
            1.0,
            15,
            1.6
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'bottom',
        ));

    await _mapController!.addCircleLayer(
        _kBusSourceId,
        'bus-selected-halo-layer',
        const CircleLayerProperties(
          circleRadius: 18.0,
          circleColor: '#00A859',
          circleOpacity: 0.45,
          circleBlur: 0.8,
          circleStrokeWidth: 0.0,
        ),
        filter: [
          '==',
          ['get', 'isSelected'],
          true
        ]);

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
          iconSize: [
            // MapLibre nativo permite UNA interpolación por zoom por
            // expresión; el tamaño según selección se elige en el output
            // con un 'case' en formato plano (cond → valor, else).
            'interpolate',
            ['linear'],
            ['zoom'],
            11,
            [
              'case',
              [
                '==',
                ['get', 'isSelected'],
                true
              ],
              0.9,
              0.7
            ],
            15,
            [
              'case',
              [
                '==',
                ['get', 'isSelected'],
                true
              ],
              1.25,
              1.0
            ]
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconRotate: ['get', 'heading'],
          iconRotationAlignment: 'map',
        ));

    _mapController!.onFeatureTapped
        .add((point, coordinates, id, layerId, annotation) async {
      await _selectBusAtTap(point);
    });

    // Arrastre del pin del usuario (UX tipo Google Maps): el gesto empieza
    // sobre el pin (feature 'draggable') y la plataforma lo consume en vez de
    // panear el mapa. 'drag' pinta el pin donde está el dedo en vivo y 'end'
    // lo guarda como pin manual (cancela el GPS si estaba activo).
    _mapController!.onFeatureDrag
        .add((point, origin, current, delta, id, annotation, eventType) {
      if (id != _kUserPinFeatureId || !mounted) return;
      switch (eventType) {
        case DragEventType.start:
          _pinDragging = true;
          break;
        case DragEventType.drag:
          // El punto del gesto ES la posición del pin en pantalla: el pulso
          // sigue al dedo sin proyecciones (la cámara no se mueve).
          _renderPin(current.latitude, current.longitude);
          setState(() => _pinScreenPos =
              Offset(point.x.toDouble(), point.y.toDouble() + _pinTipOffset));
          break;
        case DragEventType.end:
          _pinDragging = false;
          ref
              .read(userLocationProvider.notifier)
              .setManualPin(current.latitude, current.longitude);
          unawaited(_refreshPinScreenPos());
          break;
      }
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
    try {
      final routeId = widget.routeId;
      final positions = routeId == null
          ? const <BusPosition>[]
          : ref.read(busPositionsSourceProvider(routeId)).value ??
              const <BusPosition>[];
      final screenPoints = <BusScreenPoint>[];

      // MapLibre puede devolver varios features dentro de un rectángulo. No
      // basta con tomar `features.first`: cuando dos buses están cerca, el
      // primer resultado no necesariamente es el que tocó el usuario. Se
      // proyectan las posiciones y se escoge el centro más cercano.
      for (final position in positions) {
        final screen = await _mapController!.toScreenLocation(
          LatLng(position.lat, position.lon),
        );
        screenPoints.add(BusScreenPoint(
          busId: position.busId,
          offset: Offset(screen.x.toDouble(), screen.y.toDouble()),
        ));
      }

      const maxHitRadius = 32.0;
      var busId = nearestBusId(Offset(point.x, point.y), screenPoints,
          maxDistance: maxHitRadius);
      if (busId == null) {
        // Fallback solo cuando todavía no hay snapshot local para proyectar;
        // mantiene el primer toque posible durante la carga sin reintroducir
        // el rectángulo grande que causaba selecciones equivocadas.
        if (positions.isNotEmpty) return false;
        final features = await _mapController!.queryRenderedFeaturesInRect(
          Rect.fromCenter(
            center: Offset(point.x, point.y),
            width: maxHitRadius * 2,
            height: maxHitRadius * 2,
          ),
          _kBusHitLayers,
          null,
        );
        if (features.isEmpty) return false;
        busId = features.first['properties']?['busId'] as String?;
      }
      if (busId == null || busId.isEmpty) return false;
      // La selección solo decide QUÉ bus se ve en la hoja; los avisos
      // armados en otros buses se conservan (son independientes de lo que
      // se esté mirando).
      ref.read(selectedBusesProvider.notifier).toggleBus(busId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadBusIcons() => loadBusIcons(_mapController);

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

  /// Aplica una solicitud de cámara pendiente (contador > 0) al mapa.
  void _moveToRequestedCamera() {
    final controller = _mapController;
    if (controller == null || !_layersReady || !mounted) return;
    if (ref.read(mapCameraRequestProvider) <= 0) return;
    controller.moveCamera(CameraUpdate.newLatLngZoom(
      MapCameraRequestNotifier.barranquilla,
      11.5,
    ));
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

    _guideBusPosition = positions.isEmpty
        ? null
        : positions.firstWhere(
            (position) => !position.isGhostBus,
            orElse: () => positions.first,
          );
    unawaited(_refreshGuideBusTarget());

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
          ? displayOf(existing, now)
          : (prev.lat, prev.lon, prev.heading);
      _busMotions[id] = BusMotion(
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

  /// Convierte el primer bus visible en un rect global para que la guía pueda
  /// iluminar un bus real. El mapa nativo entrega coordenadas locales; se
  /// convierten a globales porque el spotlight vive por encima del Scaffold.
  Future<void> _refreshGuideBusTarget() async {
    final position = _guideBusPosition;
    final controller = _mapController;
    if (position == null || controller == null || !mounted || !_layersReady) {
      widget.onGuideBusTargetChanged?.call(null);
      return;
    }
    try {
      final screen = await controller.toScreenLocation(
        LatLng(position.lat, position.lon),
      );
      if (!mounted || _guideBusPosition != position) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      final global = box.localToGlobal(
        Offset(screen.x.toDouble(), screen.y.toDouble()),
      );
      widget.onGuideBusTargetChanged?.call(
        Rect.fromCenter(center: global, width: 76, height: 76),
      );
    } catch (_) {
      // La cámara puede no estar lista durante el primer frame. El siguiente
      // batch o el próximo onCameraIdle volverá a intentarlo.
    }
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
          ? displayOf(motion, now)
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
            key: ValueKey('map-$_mapGeneration'),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoadedCallback,
            // El mapa nativo silencia map#onMapClick cuando el toque cae sobre un
            // feature (línea de ruta, paradas, pins, buses... dentro de ±10 px) y
            // deja solo feature#onTap. Con este flag, el toque SIEMPRE dispara
            // onMapClick: se coloca el pin en cualquier lado (la selección de bus
            // se decide en _selectBusAtTap).
            featureTapsTriggersMapClick: true,
            // Al detenerse la cámara el pin queda en una posición de pantalla
            // distinta: se re-proyecta para que el pulso siga clavado en la
            // punta del pin.
            onCameraIdle: () {
              unawaited(_refreshPinScreenPos());
              unawaited(_refreshGuideBusTarget());
            },
            // Estilo Voyager de CARTO: mapa alegre y colorido (agua azul,
            // parques verdes, vías cálidas) como corresponde a Barranquilla.
            // El azul de la ruta y los buses verdes resaltan sobre él.
            styleString:
                'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
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
                    content:
                        Text('Arrastra el pin para moverlo a donde quieras'),
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
        // El radar verde del pin solo acompaña el paso de ubicación de la
        // guía. Fuera de ese paso no debe flotar sobre el mapa (ni asomarse
        // detrás de las hojas de empresa/ruta).
        if (_pinScreenPos != null &&
            ref.watch(mapGuideProvider).step == MapGuideStep.location)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _haloCtrl,
                builder: (context, _) => CustomPaint(
                  painter: _HaloPainter(
                    center: _pinScreenPos!,
                    phase: _haloCtrl.value,
                  ),
                ),
              ),
            ),
          ),
        _buildStylePlaceholder(),
        _buildStyleFailedBanner(),
      ],
    );
  }

  /// Si el estilo del mapa no llegó a cargar (red lenta, CDN bloqueado), en
  /// vez de una pantalla inerte se ofrece reintentar.
  Widget _buildStyleFailedBanner() {
    if (!_styleFailed) return const SizedBox.shrink();
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No se pudo cargar el mapa',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              TextButton(
                onPressed: _retryMap,
                child: const Text(
                  'Reintentar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
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
        if (!visible && _placeholderShown) {
          setState(() => _placeholderShown = false);
        }
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

/// Pulso "radar" bajo el pin del usuario: un círculo verde que crece y se
/// desvanece en bucle, con un punto sólido en el centro que marca el punto
/// exacto de espera. Todo el dibujo es Flutter puro encima del mapa nativo.
class _HaloPainter extends CustomPainter {
  const _HaloPainter({required this.center, required this.phase});

  final Offset center;

  /// 0..1 dentro del ciclo de 1.8 s del AnimationController.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final t = phase.clamp(0.0, 1.0);
    final radius = 14.0 + 30.0 * t;
    final opacity = (1.0 - t) * 0.32;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF00A859).withValues(alpha: opacity),
    );
    canvas.drawCircle(
      center,
      5,
      Paint()..color = const Color(0xFF00A859).withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.phase != phase;
}
