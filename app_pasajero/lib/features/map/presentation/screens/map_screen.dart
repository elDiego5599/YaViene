import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../services/background_keep_alive.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/map_guide_copy.dart';
import '../providers/map_tour_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/realtime_providers.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';
import '../utils/map_constants.dart';
import '../widgets/eta_bottom_sheet.dart';
import '../widgets/idle_status_chip.dart';
import '../widgets/location_status_chip.dart';
import '../widgets/map_tour_overlay.dart';
import '../widgets/map_widget.dart';
import '../widgets/premium_drawer.dart';
import '../widgets/search_pill_bar.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final GlobalKey<PremiumDrawerState> _drawerKey =
      GlobalKey<PremiumDrawerState>();
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

  Rect? _guideTarget;
  MapGuideStep? _measuredGuideStep;
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
      ref.read(proximityAlertsProvider.notifier).restore(
            userId: ref.read(authProvider).state.uid,
          );
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
          userId: ref.read(authProvider).state.uid,
          isNewUser: ref.read(authProvider).state.isNewUser,
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
        }
        return;
      }
      if (attempt < 12) _scheduleGuideMeasurement(step, attempt + 1);
    });
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
    return Rect.fromLTRB(
      mapRect.left + horizontalInset,
      top,
      mapRect.right - horizontalInset,
      bottom,
    );
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
          bool alertLimitReached) =>
      guideCopyFor(
        step,
        hasActiveAlert: selectedBusHasActiveAlert,
        limitReached: alertLimitReached,
        isBlocked: _alertBlocked,
      );

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(selectedRouteProvider);
    // F7: mientras el mapa se está preparando, la píldora de ubicación y la
    // de conexión no deben amontonarse sobre el "Preparando tu mapa…" — un
    // solo estado de carga en vez de tres independientes.
    final mapPreparing = ref.watch(mapPreparingProvider);
    final guide = ref.watch(mapGuideProvider);
    final step = guide.step;
    final activeAlerts = ref.watch(activeAlertsProvider);
    final selectedBusHasActiveAlert =
        ref.watch(selectedBusesProvider).any(activeAlerts.contains);
    final alertLimitReached = activeAlerts.length >= 2;
    final copy = step == null
        ? null
        : _copyFor(step, selectedBusHasActiveAlert, alertLimitReached);
    final showMapGuide = copy != null &&
        _isMapStep(step) &&
        (step == MapGuideStep.background ||
            (_guideTarget != null && _measuredGuideStep == step));
    final visibleStep = showMapGuide && step != null ? step : null;
    final isCenteredStep = visibleStep == MapGuideStep.background;
    final alertBlockedCopy = visibleStep == MapGuideStep.alert &&
        _alertBlocked &&
        !selectedBusHasActiveAlert &&
        !alertLimitReached;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      drawer: PremiumDrawer(key: _drawerKey),
      onDrawerChanged: (opened) {
        if (opened) _drawerKey.currentState?.playEntrance();
      },
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              key: _mapKey,
              routeId: selectedRoute?.id,
              onGuideBusTargetChanged: _onGuideBusTargetChanged,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
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
                if (!mapPreparing) ...[
                  const SizedBox(height: 8),
                  LocationStatusChip(routeId: selectedRoute?.id),
                  const SizedBox(height: 8),
                  const IdleStatusChip(),
                ],
              ],
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
              onGuideAlertBlocked: _onGuideAlertBlocked,
            ),
          ),
          if (visibleStep != null && copy != null)
            Positioned.fill(
              child: MapGuideOverlay(
                target: _guideTarget ?? Rect.zero,
                targetPadding: visibleStep == MapGuideStep.location ? 0 : 10,
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
