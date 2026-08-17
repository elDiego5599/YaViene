import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/providers/app_state.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/map_pattern_painter.dart';
import '../../../../services/background_keep_alive.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/realtime_providers.dart';
import '../providers/tracking_providers.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(realtimeServiceProvider).connect();
      ref.read(userLocationProvider.notifier).initialize();
      ref.read(proximityAlertsProvider.notifier).start();
      // La app siempre funciona en segundo plano: el servicio mantiene el
      // proceso vivo para que el socket siga conectado y los avisos lleguen.
      BackgroundKeepAlive.start();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(selectedRouteProvider);

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
        ],
      ),
    );
  }
}

class _PremiumDrawer extends ConsumerStatefulWidget {
  const _PremiumDrawer();

  @override
  ConsumerState<_PremiumDrawer> createState() => _PremiumDrawerState();
}

class _PremiumDrawerState extends ConsumerState<_PremiumDrawer>
    with SingleTickerProviderStateMixin {
  /// Entrada escalonada: cada bloque aparece con fade + deslizamiento leve
  /// desde la izquierda, sin blur ni efectos caros.
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Widget _staggered(Widget child, double start) {
    final animation = CurvedAnimation(
      parent: _entrance,
      curve: Interval(
        start,
        (start + 0.3).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.08, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).state;
    final email = auth.email;
    final name = (auth.name ?? '').trim();
    final activeAlerts = ref.watch(activeAlertsProvider);

    return Drawer(
      backgroundColor: const Color(0xFF0B1628),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: CustomPaint(
          painter: const MapPatternPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _staggered(
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icon/ya_viene_logo.svg',
                        width: 30,
                        height: 30,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Ya Viene',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF8FAFC),
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                  0.0,
                ),
                const SizedBox(height: 28),
                _staggered(
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
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A859),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isNotEmpty ? 'Hola, $name' : 'Hola',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF8FAFC),
                                  letterSpacing: -0.4,
                                ),
                              ),
                              if (email != null && email.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  0.08,
                ),
                const SizedBox(height: 26),
                _staggered(const _ActiveRouteCard(), 0.16),
                const SizedBox(height: 30),
                _staggered(
                  _DrawerItem(
                    icon: Icons.notifications_none_rounded,
                    bgColor: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    title: 'Avisos',
                    trailing: activeAlerts.isEmpty
                        ? const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0x4DFFFFFF),
                            size: 20,
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFB8B6B),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${activeAlerts.length}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/notifications');
                    },
                  ),
                  0.24,
                ),
                const Spacer(),
                _staggered(
                  Column(
                    children: [
                      Divider(color: Colors.white.withValues(alpha: 0.12)),
                      const SizedBox(height: 18),
                      _DrawerItem(
                        icon: Icons.logout_rounded,
                        bgColor: const Color(0xFFFEE2E2),
                        iconColor: const Color(0xFFDC2626),
                        title: 'Cerrar sesión',
                        onTap: () async {
                          await signOutAndGoToLogin(ref, context);
                        },
                      ),
                    ],
                  ),
                  0.32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pieza central del drawer: la ruta que el usuario está siguiendo, con chip
/// EN VIVO y sus terminales. Sin ruta seleccionada muestra el estado vacío.
class _ActiveRouteCard extends ConsumerWidget {
  const _ActiveRouteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(selectedRouteProvider);
    final hasRoute = route != null;
    final a = route?.terminalA ?? '';
    final b = route?.terminalB ?? '';
    final showTerminals = hasRoute && (a.isNotEmpty || b.isNotEmpty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasRoute
            ? const Color(0x1A00A859)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasRoute
              ? const Color(0x3300A859)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RUTA ACTIVA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFF94A3B8),
                ),
              ),
              if (hasRoute) const _LiveChip(),
            ],
          ),
          const SizedBox(height: 12),
          if (hasRoute) ...[
            Text(
              route.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF8FAFC),
                letterSpacing: -0.5,
              ),
            ),
            if (showTerminals) ...[
              const SizedBox(height: 14),
              _TerminalsLine(a: a, b: b),
            ],
          ] else ...[
            const Text(
              'Sin ruta activa',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF8FAFC),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Elige tu ruta en el mapa',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip "EN VIVO" con punto verde pulsante (opacity, sin efectos costosos).
class _LiveChip extends StatefulWidget {
  const _LiveChip();

  @override
  State<_LiveChip> createState() => _LiveChipState();
}

class _LiveChipState extends State<_LiveChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x1A00A859),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_pulse),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'EN VIVO',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: Color(0xFF4ADE80),
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea minimalista entre los dos terminales: trazo tenue con punto central.
class _TerminalsLine extends StatelessWidget {
  final String a;
  final String b;

  const _TerminalsLine({required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: Color(0xFF94A3B8),
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            a,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 1,
                color: Colors.white.withValues(alpha: 0.22),
              ),
              const SizedBox(width: 3),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFF00A859),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 3),
              Container(
                width: 14,
                height: 1,
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            b,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: textStyle,
          ),
        ),
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.title,
    this.trailing,
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
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
