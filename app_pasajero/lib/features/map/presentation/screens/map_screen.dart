import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../services/background_keep_alive.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/map_guide_copy.dart';
import '../providers/map_tour_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/realtime_providers.dart';
import '../providers/route_reach_provider.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';
import '../utils/bus_semantics.dart';
import '../utils/map_constants.dart';
import '../widgets/app_drawer.dart';
import '../widgets/cabecera_flotante.dart';
import '../widgets/eta_bottom_sheet.dart';
import '../widgets/idle_status_chip.dart';
import '../widgets/location_status_chip.dart';
import '../widgets/map_tour_overlay.dart';
import '../widgets/map_widget.dart';
import '../widgets/search_pill_bar.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final GlobalKey<AppDrawerState> _drawerKey =
      GlobalKey<AppDrawerState>();
  final GlobalKey _mapKey = GlobalKey();
  final GlobalKey _pillKey = GlobalKey();
  final GlobalKey _searchActionKey = GlobalKey();
  final GlobalKey _companyGuideKey = GlobalKey();
  final GlobalKey _companyChoiceGuideKey = GlobalKey();
  final GlobalKey _routeGuideKey = GlobalKey();
  final GlobalKey _routeChoiceGuideKey = GlobalKey();
  final GlobalKey _launchBusesGuideKey = GlobalKey();
  final GlobalKey _metricGuideKey = GlobalKey();
  final GlobalKey _metricUnitGuideKey = GlobalKey();
  final GlobalKey _detailGuideKey = GlobalKey();
  final GlobalKey _alertGuideKey = GlobalKey();
  final GlobalKey _recenterGuideKey = GlobalKey();

  Rect? _guideTarget;
  MapGuideStep? _measuredGuideStep;
  bool _busesEncuadrado = false;
  bool _alertBlocked = false;

  ProviderSubscription<UserLocationState>? _locationSub;
  ProviderSubscription<MapGuideState>? _guideSub;
  ProviderSubscription<Set<String>>? _busSub;

  @override
  void initState() {
    super.initState();
    _locationSub = ref.listenManual<UserLocationState>(
      userLocationProvider,
      (previous, next) {
        if (next.hasPosition &&
            ref.read(mapGuideProvider).step == MapGuideStep.location) {
          ref.read(mapGuideProvider.notifier).complete(MapGuideStep.location);
        }
        _initializeGuide();
      },
    );
    _guideSub = ref.listenManual<MapGuideState>(
      mapGuideProvider,
      (previous, next) {
        if (previous?.step != next.step) {
          _guideTarget = null;
          _measuredGuideStep = null;
          _busesEncuadrado = false;
          ref.read(mapGuideFocusProvider.notifier).state = null;
          _scheduleGuideMeasurement(next.step);
        }
      },
    );
    _busSub = ref.listenManual<Set<String>>(
      selectedBusesProvider,
      (previous, next) {
        if (next.isNotEmpty &&
            ref.read(mapGuideProvider).step == MapGuideStep.buses) {
          ref.read(mapGuideProvider.notifier).complete(MapGuideStep.buses);
        }
      },
    );
    // El paso de alerta NO se completa solo cuando ya hay un aviso activo:
    // la guía lo muestra ("Aviso ya activado") y deja que el usuario avance
    // con "Continuar" (un aviso restaurado de otra sesión no debe saltarse
    // el paso en silencio).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeGuide();
      ref.read(realtimeServiceProvider).connect();
      ref.read(userLocationProvider.notifier).initialize();
      ref.read(proximityAlertsProvider.notifier).restore();
      ref.read(proximityAlertsProvider.notifier).start();
      BackgroundKeepAlive.start();
    });
  }

  @override
  void dispose() {
    _locationSub?.close();
    _guideSub?.close();
    _busSub?.close();
    super.dispose();
  }

  Future<void> _initializeGuide() async {
    if (!mounted) return;
    final location = ref.read(userLocationProvider);
    final locationSettled = location.mode != UserLocationMode.unknown &&
        location.mode != UserLocationMode.locating;
    await ref.read(mapGuideProvider.notifier).initialize(
          hasLocation: location.hasPosition,
          locationSettled: locationSettled,
          hasRoute: ref.read(selectedRouteProvider) != null,
          hasSelectedBus: ref.read(selectedBusesProvider).isNotEmpty,
          hasActiveAlert: ref.read(activeAlertsProvider).isNotEmpty,
        );
    if (!mounted) return;
    final guide = ref.read(mapGuideProvider);
    if (location.hasPosition && guide.step == MapGuideStep.location) {
      await ref.read(mapGuideProvider.notifier).complete(MapGuideStep.location);
    }
    _scheduleGuideMeasurement(ref.read(mapGuideProvider).step);
  }

  void _onSearchOpened() {
    if (ref.read(mapGuideProvider).step == MapGuideStep.search) {
      ref.read(mapGuideProvider.notifier).complete(MapGuideStep.search);
    }
  }

  void _onGuideBusTargetChanged(Rect? _) {
    if (!mounted) return;
    if (ref.read(mapGuideProvider).step == MapGuideStep.buses) {
      _scheduleGuideMeasurement(MapGuideStep.buses);
    }
  }

  void _onGuideAlertBlocked(bool blocked) {
    if (!mounted || _alertBlocked == blocked) return;
    setState(() => _alertBlocked = blocked);
  }

  void _scheduleGuideMeasurement(MapGuideStep? step, [int attempt = 0]) {
    if (!mounted || !_isMapStep(step)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(mapGuideProvider).step != step) return;
      final rect = _targetFor(step!);
      if (rect != null && rect.width > 0 && rect.height > 0) {
        if (_guideTarget != rect || _measuredGuideStep != step) {
          setState(() {
            _guideTarget = rect;
            _measuredGuideStep = step;
          });
          // La hoja ETA anima su altura (AnimatedSize) y contenido
          // (AnimatedSwitcher): el objetivo se mueve durante unos frames, lo
          // seguimos mientras cambie y nos detenemos cuando se asienta.
          if (attempt < 40) _scheduleGuideMeasurement(step, attempt + 1);
        } else if (step == MapGuideStep.buses) {
          _encuadrarBuses(rect);
        }
        return;
      }
      if (attempt < 12) _scheduleGuideMeasurement(step, attempt + 1);
    });
  }

  /// Lleva el punto de espera al centro del área iluminada del paso de los
  /// buses, una vez por paso y ya con el área quieta.
  ///
  /// Se hace aquí y no al pulsar «Ver buses en vivo»: en ese momento la
  /// hoja todavía era la del selector, alta, y la cámara centraba el pin en
  /// el poco mapa que ella dejaba ver; al bajar la hoja el pin se quedaba
  /// arriba, bajo la tarjeta de la guía. Sin pin no se mueve nada: la
  /// cámara ya enseña la ruta.
  void _encuadrarBuses(Rect area) {
    if (_busesEncuadrado) return;
    _busesEncuadrado = true;
    if (!ref.read(userLocationProvider).hasPosition) return;
    ref.read(mapGuideFocusProvider.notifier).state = area;
    ref.read(mapRecenterRequestProvider.notifier).recenter();
  }

  bool _isMapStep(MapGuideStep? step) => isMapGuideStep(step);

  Rect? _targetFor(MapGuideStep step) {
    switch (step) {
      case MapGuideStep.location:
        final mapRect = _rectFor(_mapKey);
        if (mapRect == null) return null;
        // Empieza debajo de la barra de búsqueda y el chip de ubicación: solo
        // el área iluminada recibe el toque y el usuario no puede desviarse.
        // La altura deja espacio abajo para la tarjeta de la guía.
        final top = mapRect.top + 210;
        final height = (mapRect.height * 0.5).clamp(160.0, 400.0);
        return Rect.fromLTWH(
          mapRect.left + 16,
          top,
          mapRect.width - 32,
          height,
        );
      case MapGuideStep.search:
        return _rectFor(_searchActionKey) ?? _rectFor(_pillKey);
      case MapGuideStep.buses:
        return _mapGuideArea();
      case MapGuideStep.distance:
        final metric = _rectFor(_metricGuideKey);
        final unit = _rectFor(_metricUnitGuideKey);
        if (metric == null) return unit ?? _rectFor(_detailGuideKey);
        if (unit == null) return metric;
        // El objetivo abarca el número grande y su unidad ("km de ti").
        return metric.expandToInclude(unit);
      case MapGuideStep.alert:
      case MapGuideStep.background:
        return _rectFor(_alertGuideKey);
      case MapGuideStep.company:
      case MapGuideStep.route:
      case MapGuideStep.launchBuses:
        return null;
    }
  }

  Rect? _rectFor(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || box.size.width <= 0) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// El usuario necesita poder mover el mapa y tocar cualquier bus. Se
  /// ilumina una zona amplia del mapa, no un punto fijo que desaparece al
  /// mover la cámara. Empieza debajo de la pill y los chips para que esas
  /// acciones (quitar el pin, abrir la búsqueda) no queden dentro del área
  /// iluminada y el usuario no se desvíe del flujo.
  Rect? _mapGuideArea() {
    final mapRect = _rectFor(_mapKey);
    if (mapRect == null) return null;
    final top = mapRect.top + 210;
    // Deja 310 px libres abajo: la tarjeta de la guía (y la barra de
    // navegación) no deben solapar el área iluminada.
    final bottom = mapRect.bottom - MapConstants.guideBottomInset;
    if (bottom - top < 220) return mapRect.deflate(12);
    final horizontalInset = (mapRect.width * 0.08).clamp(24.0, 32.0);
    var right = mapRect.right - horizontalInset;
    var abajo = bottom;
    // El botón de recentrar entra entero en el área: con el pin de espera
    // puesto es lo primero que alguien quiere tocar al ver los buses, y
    // quedaba partido por el borde del hueco —la mitad iluminada, la otra
    // mitad tras el velo—. El hueco crece 10 por lado sobre esta caja, así
    // que se descuentan aquí: por abajo termina justo donde empieza la hoja
    // (el botón va 8 por encima de ella) y por la derecha deja 4 de aire.
    final boton = ref.read(userLocationProvider).hasPosition
        ? _rectFor(_recenterGuideKey)
        : null;
    if (boton != null) {
      right = math.max(right, boton.right + 4 - 10);
      abajo = math.max(abajo, boton.bottom + AppSpacing.sm - 10);
    }
    // Simétrica: la izquierda se aparta del borde lo mismo que la derecha.
    final lado = mapRect.right - right;
    return Rect.fromLTRB(mapRect.left + lado, top, right, abajo);
  }

  void _skipGuide() {
    ref.read(mapGuideProvider.notifier).skip();
    if (mounted) {
      setState(() {
        _guideTarget = null;
        _measuredGuideStep = null;
      });
    }
  }

  void _completeInfoStep(MapGuideStep step) {
    ref.read(mapGuideProvider.notifier).complete(step);
  }

  /// F14: retrocede un paso de la guía — antes solo se podía avanzar o
  /// saltarla entera, sin forma de repasar la instrucción anterior.
  void _goBackGuideStep(MapGuideStep step) {
    final previousIndex = step.index - 1;
    if (previousIndex < 0) return;
    ref
        .read(mapGuideProvider.notifier)
        .moveTo(MapGuideStep.values[previousIndex]);
  }

  void _chooseAnotherBus() async {
    ref.read(selectedBusesProvider.notifier).clear();
    await ref.read(mapGuideProvider.notifier).moveTo(MapGuideStep.buses);
  }

  MapGuideCopy _copyFor(MapGuideStep step, bool selectedBusHasActiveAlert,
          bool alertLimitReached, bool routeTooFar) =>
      guideCopyFor(
        step,
        hasActiveAlert: selectedBusHasActiveAlert,
        limitReached: alertLimitReached,
        isBlocked: _alertBlocked,
        routeTooFar: routeTooFar,
      );

  /// Las acciones que el mapa ofrece a un lector de pantalla: una por bus
  /// de la ruta, con su placa y a cuánto está. El texto y el motivo están en
  /// `utils/bus_semantics.dart`; aquí sólo se conectan con la selección.
  Map<CustomSemanticsAction, VoidCallback> _accionesDeBuses(
      RouteInfo? selectedRoute) {
    if (selectedRoute == null) return const {};
    final buses =
        ref.watch(busPositionsSourceProvider(selectedRoute.id)).value ??
            const <BusPosition>[];
    if (buses.isEmpty) return const {};

    final location = ref.watch(userLocationProvider);
    final acciones = accionesDeBuses(
      buses: buses,
      userLat: location.hasPosition ? location.lat : null,
      userLon: location.hasPosition ? location.lon : null,
      seleccionados: ref.watch(selectedBusesProvider),
    );
    return {
      for (final accion in acciones)
        CustomSemanticsAction(label: accion.etiqueta): () {
          ref.read(selectedBusesProvider.notifier).toggleBus(accion.busId);
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(selectedRouteProvider);
    // F7: mientras el mapa se está preparando, la píldora de ubicación y la
    // de conexión no deben amontonarse sobre el "Preparando tu mapa…" — un
    // solo estado de carga en vez de tres independientes.
    final mapPreparing = ref.watch(mapPreparingProvider);
    // Con el selector arriba, el grupo flotante de la cabecera se aparta,
    // igual que la hoja de abajo. El velo del selector es tinta al 40% a
    // pantalla completa: debajo, la píldora blanca y el medallón de
    // ubicación no desaparecen, se ensucian —blanco que se vuelve gris
    // azulado, verde que se apaga—, que es la única parte de la app donde
    // un color sale distinto de como se eligió. Y no tienen nada que hacer
    // ahí: mientras se elige ruta, la ruta se elige en la tarjeta.
    final cabeceraApartada = ref.watch(routeSelectorOpenProvider);
    final guide = ref.watch(mapGuideProvider);
    final step = guide.step;
    final activeAlerts = ref.watch(activeAlertsProvider);
    final selectedBusHasActiveAlert =
        ref.watch(selectedBusesProvider).any(activeAlerts.contains);
    final alertLimitReached = activeAlerts.length >= 2;
    // La guía tiene que saber POR QUÉ está bloqueado el botón del aviso: si es
    // porque la ruta no pasa cerca, mandar a "elegir otro bus" es un callejón
    // sin salida (ningún bus de esa ruta se va a acercar).
    final routeTooFar = selectedRoute == null
        ? false
        : ref.watch(routeTooFarFromUserProvider(selectedRoute.id));
    final copy = step == null
        ? null
        : _copyFor(
            step, selectedBusHasActiveAlert, alertLimitReached, routeTooFar);
    final showMapGuide = copy != null &&
        _isMapStep(step) &&
        (step == MapGuideStep.background ||
            (_guideTarget != null && _measuredGuideStep == step));
    final visibleStep = showMapGuide && step != null ? step : null;
    final isCenteredStep = visibleStep == MapGuideStep.background;
    // Solo este caso convierte el botón principal de la guía en "elegir otro
    // bus". Con la ruta lejos la copia es otra y su botón sigue siendo
    // "Continuar": cambiar de bus no destrabaría nada.
    final alertBlockedCopy = visibleStep == MapGuideStep.alert &&
        _alertBlocked &&
        !selectedBusHasActiveAlert &&
        !alertLimitReached &&
        !routeTooFar;

    final accionesDeBuses = _accionesDeBuses(selectedRoute);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      drawer: AppDrawer(key: _drawerKey),
      onDrawerChanged: (opened) {
        if (opened) _drawerKey.currentState?.playEntrance();
      },
      body: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              // El mapa es una vista nativa: no aporta nada al árbol de
              // semántica, así que con VoiceOver la mitad de la pantalla
              // es un hueco mudo. No se puede fingir que se lee —los
              // buses son puntos en un dibujo—, pero sí decir qué es y
              // dónde está lo mismo dicho con palabras: la distancia vive
              // en la hoja de abajo.
              label: selectedRoute == null
                  ? 'Mapa. Elige tu ruta arriba para ver sus buses'
                  : accionesDeBuses.isEmpty
                      ? 'Mapa con los buses de ${selectedRoute.name}. '
                          'La distancia se lee en la tarjeta de abajo'
                      : 'Mapa con ${accionesDeBuses.length} buses de '
                          '${selectedRoute.name}. Elige uno en las acciones '
                          'disponibles; la distancia se lee en la tarjeta '
                          'de abajo',
              customSemanticsActions: accionesDeBuses,
              child: MapWidget(
                key: _mapKey,
                routeId: selectedRoute?.id,
                onGuideBusTargetChanged: _onGuideBusTargetChanged,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // El mismo techo que la hoja de abajo y el selector: al doble
            // se cumple la norma de accesibilidad (WCAG 1.4.4) y las
            // píldoras siguen siendo píldoras. Era el único grupo flotante
            // sin tope, y a escala 3 la barra de búsqueda, el estado de
            // ubicación y el de conexión se comían la pantalla hasta
            // tapar el mapa que están describiendo.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 2.0,
              child: CabeceraFlotante(
                apartada: cabeceraApartada,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SearchPillBar(
                      pillKey: _pillKey,
                      searchActionKey: _searchActionKey,
                      companyGuideKey: _companyGuideKey,
                      companyChoiceGuideKey: _companyChoiceGuideKey,
                      routeGuideKey: _routeGuideKey,
                      routeChoiceGuideKey: _routeChoiceGuideKey,
                      launchBusesGuideKey: _launchBusesGuideKey,
                      onSearchOpened: _onSearchOpened,
                    ),
                    // Los dos estados aparecen cuando el mapa termina de
                    // prepararse. Antes lo hacían de golpe, empujando la
                    // cabecera un cuadro para otro; ahora se abren hacia
                    // abajo mientras se funden.
                    AnimatedSwitcher(
                      duration: AppMotion.duracion(context, AppMotion.pausado),
                      switchInCurve: AppMotion.curvaCambio,
                      switchOutCurve: AppMotion.curvaCambio,
                      transitionBuilder: (child, animation) => SizeTransition(
                        sizeFactor: animation,
                        alignment: Alignment.topCenter,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: mapPreparing
                          ? const SizedBox.shrink(
                              key: ValueKey('estados-ocultos'))
                          : Column(
                              key: const ValueKey('estados'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 8),
                                LocationStatusChip(routeId: selectedRoute?.id),
                                const SizedBox(height: 8),
                                const IdleStatusChip(),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: EtaBottomSheet(
              alertKey: _alertGuideKey,
              metricKey: _metricGuideKey,
              metricUnitKey: _metricUnitGuideKey,
              detailKey: _detailGuideKey,
              recenterKey: _recenterGuideKey,
              onGuideAlertBlocked: _onGuideAlertBlocked,
              enRespaldo: ref.watch(enRespaldoProvider),
            ),
          ),
          if (visibleStep != null && copy != null)
            Positioned.fill(
              child: MapGuideOverlay(
                target: _guideTarget ?? Rect.zero,
                targetPadding: visibleStep == MapGuideStep.location ? 0 : 10,
                cartaAbajo: visibleStep == MapGuideStep.buses,
                centered: isCenteredStep,
                title: copy.title,
                message: copy.message,
                icon: copy.icon,
                stepIndex: mapGuideStepIndex(guide, visibleStep),
                stepCount: mapGuideStepCount(guide),
                primaryLabel: copy.primaryLabel,
                onPrimary: copy.primaryLabel == null
                    ? null
                    : () => alertBlockedCopy
                        ? _chooseAnotherBus()
                        : _completeInfoStep(visibleStep),
                onBack: mapGuideStepIndex(guide, visibleStep) > 0
                    ? () => _goBackGuideStep(visibleStep)
                    : null,
                onSkip: _skipGuide,
              ),
            ),
        ],
      ),
    );
  }
}
