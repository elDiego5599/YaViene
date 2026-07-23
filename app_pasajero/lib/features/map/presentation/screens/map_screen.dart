import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../widgets/eta_bottom_sheet.dart';
import '../widgets/idle_status_chip.dart';
import '../widgets/map_widget.dart';
import '../widgets/search_pill_bar.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SearchPillBar(),
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

class _PremiumDrawer extends StatelessWidget {
  const _PremiumDrawer();

  @override
  Widget build(BuildContext context) {
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A859)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Cuenta Verificada',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00A859),
                              ),
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
                icon: Icons.history_rounded,
                bgColor: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF00A859),
                title: 'Historial de Rutas',
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
              _DrawerItem(
                icon: Icons.notifications_none_rounded,
                bgColor: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                title: 'Notificaciones',
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
              _DrawerItem(
                icon: Icons.settings_outlined,
                bgColor: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
                title: 'Ajustes',
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              Divider(color: Colors.white.withValues(alpha: 0.12)),
              const SizedBox(height: 16),
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
