import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/bus_notification_service.dart';
import '../../../../core/widgets/dialogo.dart';
import '../../../notifications/presentation/providers/abrir_aviso_provider.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/guia_atras.dart';
import '../providers/map_guide_copy.dart';
import '../providers/map_tour_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/realtime_providers.dart';
import '../providers/route_reach_provider.dart';
import '../providers/seguimiento_segundo_plano.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';
import '../utils/bus_semantics.dart';
import '../utils/map_constants.dart';
import '../widgets/bienvenida.dart';
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
  final GlobalKey _ruedaGuideKey = GlobalKey();
  final GlobalKey _recenterGuideKey = GlobalKey();

  Rect? _guideTarget;
  MapGuideStep? _measuredGuideStep;
  bool _busesEncuadrado = false;
  bool _alertBlocked = false;

  /// La hoja pregunta la distancia del aviso en la tarjeta del bus: la guía
  /// se aparta mientras tanto, porque su velo solo deja tocar el botón del
  /// aviso y la rueda queda debajo.
  bool _eligiendoDistancia = false;

  ProviderSubscription<UserLocationState>? _locationSub;
  ProviderSubscription<MapGuideState>? _guideSub;
  ProviderSubscription<Set<String>>? _busSub;
  StreamSubscription<AvisoTocado>? _avisosTocados;
  bool _bienvenidaAbierta = false;

  @override
  void initState() {
    super.initState();
    // Tocar un aviso abre el mapa en su bus, con la empresa y la ruta con
    // las que sonó (dueño, 2026-10-02): con la app viva llega por aquí; con
    // la app cerrada, por `tocadoAlAbrir` al primer cuadro.
    _avisosTocados = BusNotificationService.tocados.listen(_abrirAviso);
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
      // El servicio de fondo lo encienden y apagan los avisos armados: sin
      // aviso no hay nada que seguir con la app en el fondo.
      ref.read(seguimientoSegundoPlanoProvider);
      unawaited(BusNotificationService.tocadoAlAbrir().then((aviso) {
        if (aviso != null) _abrirAviso(aviso);
      }));
    });
  }

  void _abrirAviso(AvisoTocado aviso) {
    if (!mounted) return;
    // El aviso se pudo tocar con un texto legal encima o desde otra
    // pestaña: se vuelve al mapa, que es donde está el bus.
    Navigator.of(context, rootNavigator: true).popUntil((ruta) => ruta.isFirst);
    GoRouter.of(context).go(AppRoutes.map);
    unawaited(ref.read(abrirAvisoProvider)(aviso));
  }

  @override
  void dispose() {
    _locationSub?.close();
    _guideSub?.close();
    _busSub?.close();
    _avisosTocados?.cancel();
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
    if (ref.read(mapGuideProvider).bienvenida) {
      await _darBienvenida();
      if (!mounted) return;
    }
    final guide = ref.read(mapGuideProvider);
    if (location.hasPosition && guide.step == MapGuideStep.location) {
      await ref.read(mapGuideProvider.notifier).complete(MapGuideStep.location);
    }
    _scheduleGuideMeasurement(ref.read(mapGuideProvider).step);
  }

  /// La primera vez en el mapa: saludar y dejar escoger entre la guía y la
  /// app sin más (dueño, 2026-10-02). Cada lectura del GPS vuelve a pasar
  /// por `_initializeGuide`; la marca evita una segunda ventana encima.
  /// Tocar fuera es «Ir a la app»: la guía sigue en el menú.
  Future<void> _darBienvenida() async {
    if (_bienvenidaAbierta) return;
    _bienvenidaAbierta = true;
    final ver = await mostrarDialogo<bool>(
      context,
      (dialogContext) => VentanaBienvenida(
        alVerGuia: () => Navigator.of(dialogContext).pop(true),
        alIrALaApp: () => Navigator.of(dialogContext).pop(false),
      ),
    );
    _bienvenidaAbierta = false;
    final guia = ref.read(mapGuideProvider.notifier);
    if (ver ?? false) {
      await guia.empezar();
    } else {
      await guia.skip();
    }
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

  void _onEligiendoDistancia(bool eligiendo) {
    if (!mounted || _eligiendoDistancia == eligiendo) return;
    // Sin objetivo hasta medir el nuevo: si no, la copia de la rueda salía
    // un cuadro sobre el hueco del botón.
    setState(() {
      _eligiendoDistancia = eligiendo;
      _measuredGuideStep = null;
    });
    ref.read(eligiendoDistanciaProvider.notifier).state = eligiendo;
    // La tarjeta cambia de alto al abrir y al cerrar la rueda, y en el paso
    // del aviso el objetivo pasa del botón a la rueda y vuelve: se mide de
    // nuevo.
    _scheduleGuideMeasurement(ref.read(mapGuideProvider).step);
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
  /// arriba, bajo la tarjeta de la guía. Con un bus a la vista encuadra el
  /// pin con el más cercano, para que haya uno que tocar (dueño,
  /// 2026-10-16). Sin pin no se mueve nada: la cámara ya enseña la ruta.
  void _encuadrarBuses(Rect area) {
    if (_busesEncuadrado) return;
    _busesEncuadrado = true;
    if (!ref.read(userLocationProvider).hasPosition) return;
    ref.read(mapGuideFocusProvider.notifier).state = area;
    final ruta = ref.read(selectedRouteProvider);
    final cercano =
        ruta == null ? null : ref.read(busMasCercanoProvider(ruta.id));
    if (ruta != null && cercano != null) {
      ref.read(enfoqueDeBusProvider.notifier).pedir(cercano.busId, ruta.id);
    } else {
      ref.read(mapRecenterRequestProvider.notifier).recenter();
    }
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
        // Mientras elige la distancia, la tarjeta del bus con la rueda y
        // sus dos botones; el botón del aviso ya no está.
        return _rectFor(_eligiendoDistancia ? _ruedaGuideKey : _alertGuideKey);
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
        eligiendoDistancia: _eligiendoDistancia,
        plataforma: Theme.of(context).platform,
      );

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
    // Con la rueda abierta la guía se aparta, salvo en el paso del aviso:
    // ahí la rueda es el paso, y sin la guía quedaba toda la pantalla
    // encendida y tocable (dueño, 2026-10-16).
    final showMapGuide = copy != null &&
        (!_eligiendoDistancia || step == MapGuideStep.alert) &&
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            // Lo que el lector de pantalla oye del mapa va aparte: mira las
            // posiciones y la ubicación, que cambian cada poco, y no debe
            // arrastrar a toda la pantalla con ellas.
            child: _MapaConVoz(
              ruta: selectedRoute,
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
              ruedaKey: _ruedaGuideKey,
              metricKey: _metricGuideKey,
              metricUnitKey: _metricUnitGuideKey,
              detailKey: _detailGuideKey,
              recenterKey: _recenterGuideKey,
              onGuideAlertBlocked: _onGuideAlertBlocked,
              onEligiendoDistancia: _onEligiendoDistancia,
              enRespaldo: ref.watch(enRespaldoProvider),
            ),
          ),
          // T7.6: lo que tarda una posición en llegar, en el hueco que queda
          // entre la cabecera y la hoja. Solo en depuración y si se pide al
          // compilar (`RecuadroLatencia.pedido`): en release ni está en el
          // árbol, donde el recuadro tampoco se dibuja.
          if (RecuadroLatencia.pedido)
            const Positioned.fill(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: RecuadroLatencia(),
                  ),
                ),
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
                // Con la rueda abierta no hay «Atrás»: volver a la distancia
                // dejaría la rueda a medias y la guía escondida; la rueda
                // se cierra con su propio «Solo esta vez».
                onBack: _eligiendoDistancia ||
                        pasoAnterior(guide, visibleStep,
                                hayPunto: ref.watch(userLocationProvider
                                    .select((l) => l.hasPosition))) ==
                            null
                    ? null
                    : () => volverEnGuia(ref.read, visibleStep),
                onSkip: _skipGuide,
              ),
            ),
        ],
      ),
    );
  }
}

/// El mapa tal como lo oye un lector de pantalla.
///
/// El mapa es una vista nativa: no aporta nada al árbol de semántica, así
/// que con VoiceOver la mitad de la pantalla es un hueco mudo. No se puede
/// fingir que se lee —los buses son puntos en un dibujo—, pero sí decir qué
/// es y dónde está lo mismo dicho con palabras: la distancia vive en la hoja
/// de abajo. Y se ofrece una acción por bus de la ruta, con su placa y a
/// cuánto está (el texto y el motivo, en `utils/bus_semantics.dart`).
///
/// Vive aparte de [MapScreen] porque mira las posiciones de la ruta, que
/// llegan hasta cada 200 ms, y la ubicación, que cambia con cada lectura del
/// GPS. Dentro de la pantalla, cada una rehacía el Scaffold entero: la
/// cabecera, la hoja, la guía y el mapa (auditoría 2026-09, H5). Aquí se
/// rehace solo este envoltorio, y solo cuando cambia lo que se dice; el
/// [child] llega hecho y conserva su identidad.
class _MapaConVoz extends ConsumerWidget {
  const _MapaConVoz({required this.ruta, required this.child});

  final RouteInfo? ruta;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruta = this.ruta;
    final acciones =
        ruta == null ? const <AccionDeBus>[] : _acciones(ref, ruta);
    return Semantics(
      label: ruta == null
          ? 'Mapa. Elige tu ruta arriba para ver sus buses'
          : acciones.isEmpty
              ? 'Mapa con los buses de ${ruta.name}. '
                  'La distancia se lee en la tarjeta de abajo'
              : 'Mapa con ${acciones.length} buses de ${ruta.name}. Elige '
                  'uno en las acciones disponibles; la distancia se lee en '
                  'la tarjeta de abajo',
      customSemanticsActions: {
        for (final accion in acciones)
          CustomSemanticsAction(label: accion.etiqueta): () {
            ref.read(selectedBusesProvider.notifier).toggleBus(accion.busId);
          },
      },
      child: child,
    );
  }

  /// Las acciones de los buses, mirando con `select` solo lo que cambia su
  /// texto: el punto de espera (no el resto del estado de la ubicación) y
  /// las frases armadas con las posiciones (una foto que no cambia ninguna
  /// no despierta a nadie).
  List<AccionDeBus> _acciones(WidgetRef ref, RouteInfo ruta) {
    final punto = ref.watch(userLocationProvider.select(
      (l) => l.hasPosition ? (l.lat!, l.lon!) : null,
    ));
    final seleccionados = ref.watch(selectedBusesProvider);
    return ref
        .watch(busPositionsSourceProvider(ruta.id).select(
          (posiciones) => _Acciones(accionesDeBuses(
            buses: posiciones.value ?? const <BusPosition>[],
            userLat: punto?.$1,
            userLon: punto?.$2,
            seleccionados: seleccionados,
          )),
        ))
        .lista;
  }
}

/// Una lista de acciones que se compara por lo que dice: `select` solo
/// avisa cuando el valor nuevo es distinto del anterior.
@immutable
class _Acciones {
  const _Acciones(this.lista);

  final List<AccionDeBus> lista;

  @override
  bool operator ==(Object other) =>
      other is _Acciones && listEquals(other.lista, lista);

  @override
  int get hashCode => Object.hashAll(lista);
}
