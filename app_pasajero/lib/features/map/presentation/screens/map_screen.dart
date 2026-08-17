import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../services/background_keep_alive.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/map_tour_provider.dart';
import '../providers/realtime_providers.dart';
import '../providers/user_location_provider.dart';
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
  /// Para re-disparar la entrada escalonada del drawer en CADA apertura:
  /// el drawer se construye al abrirse, así que un forward en initState solo
  /// cubriría la primera vez; el Scaffold avisa vía onDrawerChanged.
  final GlobalKey<PremiumDrawerState> _drawerKey = GlobalKey<PremiumDrawerState>();

  /// Para medir la posición de la píldora de búsqueda y abrirle el hueco del
  /// tour de primer uso.
  final GlobalKey _pillKey = GlobalKey();

  /// Rect de la píldora en pantalla; != null solo mientras el tour está vivo.
  Rect? _tourTarget;

  ProviderSubscription<UserLocationState>? _locationSub;

  @override
  void initState() {
    super.initState();
    // El tour se dispara UNA vez la ubicación está lista (GPS o pin manual):
    // iluminar la píldora antes de eso sería un tutorial a medio flujo.
    // listenManual: en initState no se puede usar ref.listen (exige build).
    _locationSub = ref.listenManual<UserLocationState>(
        userLocationProvider, (previous, next) {
      if (next.hasPosition) _maybeShowTour();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(userLocationProvider).hasPosition) _maybeShowTour();
      ref.read(realtimeServiceProvider).connect();
      ref.read(userLocationProvider.notifier).initialize();
      // Re-arma los avisos activos guardados (sobreviven al cierre de la app
      // y al cierre de sesión) y vuelve a correr el timer de verificación.
      ref.read(proximityAlertsProvider.notifier).restore();
      ref.read(proximityAlertsProvider.notifier).start();
      // La app siempre funciona en segundo plano: el servicio mantiene el
      // proceso vivo para que el socket siga conectado y los avisos lleguen.
      BackgroundKeepAlive.start();
    });
  }

  @override
  void dispose() {
    _locationSub?.close();
    super.dispose();
  }

  /// Muestra el tour de primer uso si aplica. El flag se persiste en prefs:
  /// solo se ve una vez en la vida de la instalación.
  void _maybeShowTour() async {
    if (!mounted || _tourTarget != null) return;
    await ref.read(mapTourProvider.notifier).maybeShow();
    if (!mounted || !ref.read(mapTourProvider)) return;
    // Medir la píldora después de que el frame la haya pintado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tourTarget != null) return;
      final box = _pillKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.width <= 0) return;
      setState(() => _tourTarget = rect);
    });
  }

  void _closeTour() {
    ref.read(mapTourProvider.notifier).markSeen();
    setState(() => _tourTarget = null);
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(selectedRouteProvider);

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
            child: MapWidget(routeId: selectedRoute?.id),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchPillBar(key: _pillKey),
                const SizedBox(height: 8),
                LocationStatusChip(routeId: selectedRoute?.id),
                // Estado de la conexión: se muestra con o sin ruta activa.
                const SizedBox(height: 8),
                const IdleStatusChip(),
              ],
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: EtaBottomSheet(),
          ),
          if (_tourTarget != null)
            Positioned.fill(
              child: MapTourOverlay(
                target: _tourTarget!,
                onDone: _closeTour,
              ),
            ),
        ],
      ),
    );
  }
}

