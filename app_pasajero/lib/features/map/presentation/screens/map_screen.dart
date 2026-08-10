import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/providers/app_state.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/realtime_providers.dart';
import '../providers/user_location_provider.dart';
import '../widgets/eta_bottom_sheet.dart';
import '../widgets/idle_status_chip.dart';
import '../widgets/location_status_chip.dart';
import '../widgets/map_widget.dart';
import '../widgets/search_pill_bar.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  /// El aviso de "toca el mapa" solo se muestra una vez por sesión.
  bool _locationHintShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(realtimeServiceProvider).connect();
      ref.read(userLocationProvider.notifier).initialize();
      ref.read(proximityAlertsProvider.notifier).start();
    });
  }

  void _onLocationChanged(UserLocationState state) {
    if (!mounted || _locationHintShown) return;
    if (state.mode == UserLocationMode.denied ||
        state.mode == UserLocationMode.permanentDenied) {
      _locationHintShown = true;
      _showLocationHint(state.mode);
    }
  }

  Future<void> _showLocationHint(UserLocationMode mode) async {
    final permanent = mode == UserLocationMode.permanentDenied;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Indica dónde estás'),
        content: Text(
          permanent
              ? 'La ubicación está bloqueada en los Ajustes del teléfono. '
                  'Actívala ahí para ver los buses cerca de ti, o toca el mapa '
                  'en el lugar donde te encuentras.'
              : 'No pudimos obtener tu ubicación. Toca el mapa en el lugar '
                  'donde te encuentras para ver qué buses vienen hacia ti.',
        ),
        actions: [
          if (permanent)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                openAppSettings();
              },
              child: const Text('Abrir Ajustes'),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ref.read(userLocationProvider.notifier).useGps();
              },
              child: const Text('Intentar de nuevo'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(selectedRouteProvider);

    // Si la ubicación está negada al abrir la app, avisa una vez que toque
    // el mapa para indicar dónde está.
    ref.listen<UserLocationState>(userLocationProvider, (prev, next) {
      if (prev == null || prev.mode == next.mode) return;
      _onLocationChanged(next);
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      drawer: const _PremiumDrawer(),
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
                const SearchPillBar(),
                const SizedBox(height: 8),
                LocationStatusChip(routeId: selectedRoute?.id),
              ],
            ),
          ),
          if (selectedRoute == null)
            const Positioned.fill(child: IdleStatusChip()),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: EtaBottomSheet(),
          ),
        ],
      ),
    );
  }
}

class _PremiumDrawer extends ConsumerWidget {
  const _PremiumDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authProvider).state.email;

    return Drawer(
      backgroundColor: const Color(0xFF14274E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ya Viene',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A859),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pasajero',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email ?? 'Sesión iniciada',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              _DrawerItem(
                icon: Icons.person_outline_rounded,
                bgColor: const Color(0xFFEEF2FF),
                iconColor: const Color(0xFF4F46E5),
                title: 'Mi Perfil',
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
              _DrawerItem(
                icon: Icons.notifications_none_rounded,
                bgColor: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                title: 'Notificaciones',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/notifications');
                },
              ),
              const Spacer(),
              Divider(color: Colors.white.withValues(alpha: 0.12)),
              const SizedBox(height: 16),
              _DrawerItem(
                icon: Icons.logout_rounded,
                bgColor: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                title: 'Cerrar sesión',
                onTap: () async {
                  await resetAppState(ref);
                  await ref.read(authProvider).signOut();
                  if (!context.mounted) return;
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
