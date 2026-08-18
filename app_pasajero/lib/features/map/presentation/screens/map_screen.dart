import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../services/background_keep_alive.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/map_tour_provider.dart';
import '../providers/realtime_providers.dart';
import '../providers/tracking_providers.dart';
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

  /// Para medir la píldora de búsqueda y abrirle el hueco del tour de primer
  /// uso (la llave vive en el contenedor blanco real, no en el SafeArea).
  final GlobalKey _pillKey = GlobalKey();

  /// Para medir el botón de aviso en el paso 2 del tour (primer bus tocado).
  final GlobalKey _alertKey = GlobalKey();

  /// Rect del objetivo en pantalla; != null solo mientras el tour está vivo.
  Rect? _tourTarget;

  ProviderSubscription<UserLocationState>? _locationSub;
  ProviderSubscription<Set<String>>? _busSelectionSub;

  @override
  void initState() {
    super.initState();
    // El tour se dispara UNA vez la ubicación está lista (GPS o pin manual):
    // iluminar la píldora antes de eso sería un tutorial a medio flujo.
    // listenManual: en initState no se puede usar ref.listen (exige build).
    _locationSub = ref.listenManual<UserLocationState>(
        userLocationProvider, (previous, next) {
      if (next.hasPosition) _maybeShowPillTour();
    });
    // Paso 2: al tocar el PRIMER bus se ilumina el botón de aviso y se explica
    // que la app sigue avisando en segundo plano.
    _busSelectionSub = ref.listenManual<Set<String>>(
        selectedBusesProvider, (previous, next) {
      if (next.isNotEmpty && (previous?.isEmpty ?? true)) {
        _maybeShowBusTour();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(userLocationProvider).hasPosition) _maybeShowPillTour();
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
    _busSelectionSub?.close();
    super.dispose();
  }

  /// Muestra el paso 1 del tour (píldora de búsqueda) si aplica. El flag se
  /// persiste en prefs: solo se ve una vez en la vida de la instalación.
  void _maybeShowPillTour() async {
    if (!mounted || _tourTarget != null) return;
    await ref.read(mapTourProvider.notifier).maybeShow(MapTourKind.pill);
    if (!mounted || ref.read(mapTourProvider) != MapTourKind.pill) return;
    _measureAndShow(_pillKey);
  }

  /// Muestra el paso 2 (botón de aviso del bus) cuando se toca el primer bus.
  void _maybeShowBusTour() async {
    if (!mounted || _tourTarget != null) return;
    await ref.read(mapTourProvider.notifier).maybeShow(MapTourKind.bus);
    if (!mounted || ref.read(mapTourProvider) != MapTourKind.bus) return;
    // La hoja ETA tarda ~400 ms en asentarse; medir el botón de aviso en
    // cuanto termina de animar (con reintento por si el layout no pintó).
    for (var attempt = 0; attempt < 3; attempt++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || _tourTarget != null) return;
      _measureAndShow(_alertKey);
    }
  }

  /// Mide el widget bajo [key] en el siguiente frame y, si tiene tamaño,
  /// abre el tour sobre él.
  void _measureAndShow(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tourTarget != null) return;
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || box.size.width <= 0) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
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
    final tourKind = ref.watch(mapTourProvider);
    final tour = _tourTarget != null && tourKind != null
        ? _tourContent(tourKind)
        : null;

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
                SearchPillBar(pillKey: _pillKey),
                const SizedBox(height: 8),
                LocationStatusChip(routeId: selectedRoute?.id),
                // Estado de la conexión: se muestra con o sin ruta activa.
                const SizedBox(height: 8),
                const IdleStatusChip(),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: EtaBottomSheet(alertKey: _alertKey),
          ),
          if (tour != null)
            Positioned.fill(
              child: MapTourOverlay(
                target: _tourTarget!,
                title: tour.$1,
                subtitle: tour.$2,
                icon: tour.$3,
                stepIndex: tourKind == MapTourKind.pill ? 0 : 1,
                stepCount: 2,
                onDone: _closeTour,
              ),
            ),
        ],
      ),
    );
  }

  /// Contenido de cada paso del tour (título, subtítulo, icono).
  (String, String, IconData) _tourContent(MapTourKind kind) {
    switch (kind) {
      case MapTourKind.pill:
        return (
          'Elige tu ruta',
          'Toca la píldora de arriba para buscar tu línea y elegir tu '
              'sentido.',
          Icons.touch_app_rounded,
        );
      case MapTourKind.bus:
        return (
          'Activa la alarma',
          'Toca el bus y actívala: te avisaremos aunque dejes la app en '
              'segundo plano haciendo otra cosa. Solo no la cierres del todo.',
          Icons.notifications_active_rounded,
        );
    }
  }
}

