import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../providers/map_tour_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/tracking_providers.dart'
    show nearbyRadiusMeters, selectedBusesProvider;
import '../providers/user_location_provider.dart';
import '../providers/visible_buses_provider.dart' show visibleBusesProvider;
import '../utils/bus_hit_test.dart';
import '../utils/map_constants.dart' show MapConstants;
import 'halo_painter.dart';
import 'map_bus_animator.dart';
import 'map_markers.dart' show loadBusIcons;
import 'map_pin_utils.dart' show radiusCircleFeature;
import 'map_placeholders.dart';
import 'tap_debouncer.dart';

part 'map_route_data.dart';

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
    with WidgetsBindingObserver, TickerProviderStateMixin {
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

  /// El feature GeoJSON ya armado de cada bus, guardado entre cuadros.
  ///
  /// La fuente del mapa se reemplaza entera en cada empuje —MapLibre no
  /// acepta actualizar un solo punto—, así que el lote siempre lleva todos
  /// los buses. Pero solo los que están a medio tramo cambian de un cuadro
  /// al siguiente: los quietos, y los fantasmas, volvían a armar el mismo
  /// árbol de mapas treinta veces por segundo para que saliera idéntico.
  /// Aquí se arma una vez y se reutiliza el mismo objeto.
  ///
  /// Nada lo muta después de guardarlo; para cambiarlo se borra la entrada.
  /// Se invalida en los cuatro sitios donde un bus puede cambiar de aspecto:
  /// llega un paquete suyo, se acaba su tramo, cambia la selección, o se va.
  final Map<String, Map<String, Object?>> _busFeatures = {};

  /// Tramo de animación en curso por bus (interpolación entre fixes).
  final Map<String, BusMotion> _busMotions = {};

  /// El reloj que mueve los buses. Es un `Ticker` y no un `Timer.periodic`
  /// por dos razones que se notan en el teléfono:
  ///
  /// Un temporizador de 33 ms corre contra el reloj de pared, que no tiene
  /// nada que ver con el refresco de la pantalla. A 60 Hz hay un cuadro cada
  /// 16,7 ms, así que el temporizador caía unas veces justo antes del cuadro
  /// y otras justo después: el bus avanzaba a tirones aunque la cuenta fuera
  /// perfecta. En pantallas de 90 y 120 Hz el desfase es peor. El `Ticker`
  /// se dispara *con* el cuadro, así que el reparto es siempre parejo.
  ///
  /// Y un `Timer` no sabe que la app se fue al fondo: seguía empujando buses
  /// por el puente nativo con la pantalla apagada. El `Ticker` se calla solo
  /// cuando no se están pintando cuadros, y vuelve al volver.
  Ticker? _busAnimTicker;

  /// Cuándo se empujó el último lote, medido con el reloj del propio `Ticker`.
  /// null = todavía no se ha empujado nada en esta tanda.
  Duration? _ultimoEmpujeBuses;

  /// Presupuesto de empujes: uno cada 32 ms como mucho, el mismo ritmo que
  /// tenía el temporizador. No se sube a un empuje por cuadro porque cada uno
  /// cruza el puente nativo con todos los buses, y a la velocidad a la que se
  /// mueve un bus en el mapa 30 veces por segundo ya es movimiento continuo.
  /// Con este número el reparto cae en cuadros exactos: uno de cada dos a
  /// 60 Hz, uno de cada tres a 90, uno de cada cuatro a 120.
  static const Duration _kEmpujeBusesMinimo = Duration(milliseconds: 32);

  /// "Respiración" del halo del bus seleccionado: nativo (capa de círculo),
  /// no un widget Flutter, porque así sigue al bus moviéndose sin proyectar
  /// pantalla en cada frame. Solo corre mientras haya algo seleccionado —
  /// una llamada al puente cada ~900 ms, no por frame.
  Timer? _haloPulseTimer;
  bool _haloPulseOut = false;

  static const _kRouteSourceId = 'route-source';
  static const _kRouteLayerId = 'route-line';
  static const _kStopsFijaSourceId = 'stops-fija-source';
  static const _kStopsFijaLayerId = 'stops-fija-layer';
  static const _kStopsInformalSourceId = 'stops-informal-source';
  static const _kStopsInformalLayerId = 'stops-informal-layer';
  static const _kBusSourceId = 'bus-source';
  static const _kBusLayerId = 'bus-layer';
  static const _kBusHaloLayerId = 'bus-selected-halo-layer';

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
      // La selección cambia el tamaño del ícono y enciende el halo, así que
      // ningún feature guardado sirve ya. Pasa al tocar, no por cuadro.
      _busFeatures.clear();
      _pushBusSource();
      _syncHaloPulse(next);
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
    ref.read(mapPreparingProvider.notifier).state = true;
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
    // Hay que desecharlo, no solo pararlo: `TickerProviderStateMixin` afirma
    // en su propio dispose que no le queda ningún ticker vivo.
    _busAnimTicker?.dispose();
    _busAnimTicker = null;
    _haloPulseTimer?.cancel();
    _haloPulseTimer = null;
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
    final positions = ref.read(visibleBusesProvider(routeId)).value;
    if (positions != null) _updateBusSourceData(positions);
  }

  void _setupBusSubscription(String routeId) {
    _movingBusSubscription?.close();
    // Cambio de ruta: sin animación, se pinta directo (los buses son otros).
    _rawBuses.clear();
    _busMotions.clear();
    _busFeatures.clear();
    _stopBusAnimTicker();
    // Se escucha la lista YA RECORTADA al radio del punto de espera, no la
    // fuente entera: así el mapa se repinta también cuando el usuario mueve
    // su pin (entran y salen buses del radio sin esperar al próximo paquete
    // del socket), y no solo cuando llegan posiciones nuevas.
    _movingBusSubscription =
        ref.listenManual(visibleBusesProvider(routeId), (previous, next) {
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
    _busFeatures.clear();
    _stopBusAnimTicker();
    _stopHaloPulse();
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
    } catch (e, st) {
      debugPrint('_refreshPinScreenPos failed: $e\n$st');
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
        radiusCircleFeature(lat, lon, nearbyRadiusMeters.toDouble()),
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

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeId != widget.routeId && _layersReady) {
      _hasFitInitialRoute = false;
      if (widget.routeId != null) {
        reloadMapData();
        _setupBusSubscription(widget.routeId!);
      } else {
        _teardownBusSubscription();
        teardownRouteData();
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
        reloadMapData();
        _setupBusSubscription(widget.routeId!);
      }
      // Si ya había un bus seleccionado antes de que el estilo terminara de
      // cargar (p. ej. al recrear la vista nativa), el halo no debe esperar
      // al próximo cambio de selección para empezar a pulsar.
      _syncHaloPulse(ref.read(selectedBusesProvider));
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
        _kBusHaloLayerId,
        // Dorado neón, no el rojo del bus: así el halo se lee como "esto
        // está seleccionado", no como una sombra del propio ícono.
        const CircleLayerProperties(
          circleRadius: 20.0,
          circleColor: '#FFC72C',
          circleOpacity: 0.55,
          circleBlur: 0.75,
          circleStrokeWidth: 2.0,
          circleStrokeColor: '#FFF3C4',
          circleStrokeOpacity: 0.9,
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

  final _tapDebouncer = TapDebouncer();

  Future<bool> _selectBusAtTap(math.Point<double> point) =>
      _tapDebouncer.run(point, _doSelectBusAtTap);

  Future<bool> _doSelectBusAtTap(math.Point<double> point) async {
    try {
      final routeId = widget.routeId;
      // Los mismos buses que están dibujados: si uno está fuera del radio no
      // se pinta, y tocar donde estaría no puede seleccionarlo.
      final positions = routeId == null
          ? const <BusPosition>[]
          : ref.read(visibleBusesProvider(routeId)).value ??
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

      const maxHitRadius = MapConstants.busHitRadius;
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
    } catch (e, st) {
      debugPrint('_doSelectBusAtTap failed: $e\n$st');
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
    } catch (e, st) {
      debugPrint('updateContentInsets failed: $e\n$st');
    }
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
        _busFeatures.remove(id);
      }
    }

    for (final entry in byId.entries) {
      final id = entry.key;
      final pos = entry.value;
      final prev = _rawBuses[id];
      _rawBuses[id] = pos;
      // Llegó paquete suyo: aunque no se haya movido un metro pueden haber
      // cambiado la velocidad o el estado de fantasma, que también se pintan.
      _busFeatures.remove(id);

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
        Rect.fromCenter(
            center: global,
            width: MapConstants.guideBusRectSize,
            height: MapConstants.guideBusRectSize),
      );
    } catch (e, st) {
      debugPrint('_refreshGuideBusTarget failed: $e\n$st');
      // La cámara puede no estar lista durante el primer frame. El siguiente
      // batch o el próximo onCameraIdle volverá a intentarlo.
    }
  }

  /// Arranca el reloj de los buses si no está corriendo. Solo corre mientras
  /// haya algún bus a medio tramo: en cuanto se vacían, se para solo.
  void _ensureBusAnimTicker() {
    final ticker = _busAnimTicker ??= createTicker(_onBusFrame);
    if (!ticker.isActive) {
      // `start()` pone el cronómetro del ticker otra vez en cero, así que el
      // sello del último empuje tiene que irse con él o el primer cuadro de
      // la tanda nueva se compararía contra un tiempo de la tanda anterior.
      _ultimoEmpujeBuses = null;
      ticker.start();
    }
  }

  void _stopBusAnimTicker() {
    if (_busAnimTicker?.isActive ?? false) _busAnimTicker!.stop();
  }

  /// Un cuadro de animación de los buses.
  void _onBusFrame(Duration elapsed) {
    if (!mounted) {
      _stopBusAnimTicker();
      return;
    }
    final ultimo = _ultimoEmpujeBuses;
    if (ultimo != null && elapsed - ultimo < _kEmpujeBusesMinimo) return;
    _ultimoEmpujeBuses = elapsed;

    final now = DateTime.now();
    // Al acabarse un tramo hay que tirar el feature guardado además del
    // tramo. Si no, el bus se queda clavado en el último punto interpolado
    // —que va un paso corto de su destino— y ahí se queda hasta el siguiente
    // paquete, porque sin tramo vivo el empuje reutilizaría ese mismo mapa.
    _busMotions.removeWhere((id, m) {
      final terminado = m.isFinished(now);
      if (terminado) _busFeatures.remove(id);
      return terminado;
    });
    if (_mapController != null && _layersReady) {
      _pushBusSource();
    }
    if (_busMotions.isEmpty) _stopBusAnimTicker();
  }

  void _pushBusSource() {
    if (_mapController == null || !mounted || !_layersReady) return;
    final selectedBuses = ref.read(selectedBusesProvider);
    final now = DateTime.now();
    final features = <Map<String, Object?>>[];
    for (final entry in _rawBuses.entries) {
      final id = entry.key;
      final pos = entry.value;
      final motion = _busMotions[id];
      // Sin tramo vivo el bus está donde estaba: sirve el mismo feature del
      // cuadro anterior. Cualquier cosa que lo cambie ya borró la entrada.
      final guardado = _busFeatures[id];
      if (motion == null && guardado != null) {
        features.add(guardado);
        continue;
      }
      final display = motion != null
          ? displayOf(motion, now)
          : (pos.lat, pos.lon, pos.heading);
      final feature = <String, Object?>{
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
      // Solo se guarda el de un bus quieto: el de uno en marcha vale para
      // este cuadro y nada más, y dejarlo puesto sería justo el feature
      // caducado que el borrado de arriba está evitando.
      if (motion == null) _busFeatures[id] = feature;
      features.add(feature);
    }
    _mapController!.setGeoJsonSource(_kBusSourceId, {
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  /// Arranca o para la "respiración" del halo según haya algo seleccionado.
  void _syncHaloPulse(Set<String> selectedBuses) {
    if (selectedBuses.isEmpty) {
      _stopHaloPulse();
    } else {
      _startHaloPulse();
    }
  }

  /// Anima el halo nativo del bus seleccionado alternando entre un anillo
  /// dorado apretado y brillante y un resplandor más ancho y difuso — el
  /// vaivén que da la sensación de "brillar". Es una capa de MapLibre, no un
  /// widget: se mueve con el bus gratis. Solo una llamada al puente por medio
  /// ciclo (~900 ms), no por frame — el suavizado intermedio lo hace la
  /// transición por defecto del estilo.
  void _startHaloPulse() {
    if (_haloPulseTimer != null) return;
    _haloPulseOut = false;
    _haloPulseTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (_mapController == null || !mounted || !_layersReady) return;
      // En segundo plano nadie ve el latido, pero el temporizador sigue vivo y
      // cada vuelta cruza el puente hacia el mapa nativo. Es justo el caso de
      // la demo: bus seleccionado, aviso armado y la app atrás esperando.
      if (_lifecycleState != AppLifecycleState.resumed) return;
      _haloPulseOut = !_haloPulseOut;
      _mapController!.setLayerProperties(
        _kBusHaloLayerId,
        CircleLayerProperties(
          circleRadius: _haloPulseOut ? 27.0 : 16.0,
          circleOpacity: _haloPulseOut ? 0.22 : 0.68,
          circleBlur: _haloPulseOut ? 0.95 : 0.5,
          circleStrokeOpacity: _haloPulseOut ? 0.3 : 1.0,
        ),
      );
    });
  }

  void _stopHaloPulse() {
    _haloPulseTimer?.cancel();
    _haloPulseTimer = null;
    if (_mapController != null && mounted && _layersReady) {
      _mapController!.setLayerProperties(
        _kBusHaloLayerId,
        const CircleLayerProperties(
          circleRadius: 20.0,
          circleOpacity: 0.55,
          circleBlur: 0.75,
          circleStrokeOpacity: 0.9,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const ColoredBox(color: AppColors.background);
    }

    // F18: antes solo se avisaba una vez con un SnackBar que "arrastra el
    // pin para moverlo". Ahora hay un badge junto al propio pin mientras es
    // manual: se ve cada vez, no solo la primera.
    final pinIsManual =
        ref.watch(userLocationProvider).mode == UserLocationMode.manual;

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
            // El azul de la ruta y los buses rojos resaltan sobre él.
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
              // Durante el paso "location" de la guía, el único gesto
              // permitido es fijar el pin: un bus bajo el toque no debe
              // robárselo y desviar el flujo.
              final guideBlocksBusTap =
                  ref.read(mapGuideProvider).step == MapGuideStep.location;
              // Un bus cerca del toque (aunque quede debajo/encima del pin) se
              // selecciona y NO se mueve el pin manual.
              if (!guideBlocksBusTap && await _selectBusAtTap(point)) return;
              if (!mounted) return;
              final location = ref.read(userLocationProvider);
              // Con el GPS activo el pin sigue al usuario: el toque no lo mueve.
              // Durante la búsqueda de GPS el toque sí coloca el pin manual
              // (cancela la espera de localización).
              if (location.mode == UserLocationMode.gps) {
                return;
              }
              // Pin fijo: una vez puesto no se mueve con toques (evita
              // moverlo por accidente al tocar el mapa); se arrastra directo
              // (el badge junto al pin lo indica todo el tiempo, F18) o se
              // quita con "Quitar".
              if (location.mode == UserLocationMode.manual) {
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
              // El radar ocupa la pantalla entera y se repinta en cada cuadro
              // del ciclo de 1,8 s. Sin frontera, ese repintado sube hasta la
              // primera que haya por encima —aquí, fuera del Stack— y arrastra
              // con él a todo lo demás que cuelgue de ella: la vista nativa
              // del mapa, las hojas, los chips. Con la frontera el radar tiene
              // su propia capa y se repinta solo él, que es lo único que
              // cambia. Dos círculos: la capa de más sale mucho más barata que
              // repintar el árbol entero treinta y tres veces por segundo.
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _haloCtrl,
                  builder: (context, _) => CustomPaint(
                    painter: HaloPainter(
                      center: _pinScreenPos!,
                      phase: _haloCtrl.value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        // F18: badge persistente de "se puede arrastrar" sobre el pin fijo,
        // en vez de un SnackBar que solo se ve la primera vez.
        if (pinIsManual && !_pinDragging && _pinScreenPos != null)
          Positioned(
            left: _pinScreenPos!.dx - 15,
            top: _pinScreenPos!.dy - _pinTipOffset - 46,
            child: IgnorePointer(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDeep.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.open_with_rounded,
                  size: 16,
                  color: AppColors.primaryDeep,
                ),
              ),
            ),
          ),
        MapStylePlaceholder(
          layersReady: _layersReady,
          placeholderShown: _placeholderShown,
          onFadeEnd: () {
            if (mounted) setState(() => _placeholderShown = false);
            ref.read(mapPreparingProvider.notifier).state = false;
          },
        ),
        MapStyleFailedBanner(
          styleFailed: _styleFailed,
          onRetry: _retryMap,
        ),
      ],
    );
  }
}
