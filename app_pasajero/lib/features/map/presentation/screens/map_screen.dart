import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../widgets/filter_panel.dart';
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
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(routeId: selectedRoute?.id),
          ),

          const Positioned(
            top: 0, left: 0, right: 0,
            child: FilterPanel(),
          ),

          const Positioned(
            top: 0, right: 12,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(top: 12.0),
                child: _RealtimeTickDebugBadge(),
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton(
              heroTag: 'gps_btn',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF14274E),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () {},
              child: const Icon(Icons.my_location_rounded),
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

class _RealtimeTickDebugBadge extends ConsumerWidget {
  const _RealtimeTickDebugBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickAsync = ref.watch(realtimeTickProvider);
    bool isDebug = false;
    assert(() { isDebug = true; return true; }());
    if (!isDebug) return const SizedBox.shrink();

    return tickAsync.when(
      data: (tick) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Text('WS: $tick',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
