import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../widgets/search_pill_bar.dart';
import '../widgets/map_widget.dart';
import '../widgets/eta_bottom_sheet.dart';

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
            top: 0, left: 0, right: 0,
            child: SearchPillBar(),
          ),

          const Positioned(
            bottom: 120, left: 16,
            child: SafeArea(
              child: _RealtimeTickDebugBadge(),
            ),
          ),

          Positioned(
            right: AppSpacing.md,
            bottom: 140,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: AppShadows.soft,
              ),
              child: IconButton(
                iconSize: 28,
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.primaryDeep,
                onPressed: () {
                  // TODO: Centrar en GPS
                },
                icon: const Icon(Icons.my_location_rounded),
              ),
            ),
          ),

          const Positioned(
            bottom: 0, left: 0, right: 0,
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ya Viene',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 64),
              _DrawerItem(icon: Icons.person_rounded, title: 'Mi Perfil'),
              const SizedBox(height: 32),
              _DrawerItem(icon: Icons.history_rounded, title: 'Historial'),
              const SizedBox(height: 32),
              _DrawerItem(icon: Icons.settings_rounded, title: 'Ajustes'),
              const Spacer(),
              const Text(
                'v1.0.0 (BETA)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
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
  final String title;

  const _DrawerItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(width: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _RealtimeTickDebugBadge extends ConsumerWidget {
  const _RealtimeTickDebugBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickAsync = ref.watch(realtimeTickProvider);
    bool isDebug = false;
    assert(() { isDebug = true; return true; }());
    if (!isDebug) return const SizedBox.shrink();

    return tickAsync.when(
      data: (tick) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          'WS: $tick',
          style: AppTextStyles.label.copyWith(
            color: Colors.white,
            fontSize: 10,
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
