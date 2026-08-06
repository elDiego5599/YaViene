import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fleet_bus.dart';
import '../providers/fleet_providers.dart';

class ControlMap extends ConsumerWidget {
  const ControlMap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleet = ref.watch(fleetProvider);
    final markers = fleet.fleetList
        .where((b) => b.lat != null && b.lon != null)
        .map(
          (b) => _buildMarker(b, fleet.selectedBusId == b.busId, () {
            ref.read(fleetProvider.notifier).selectBus(b.busId);
          }),
        )
        .toList();

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: const LatLng(10.9639, -74.7964),
            initialZoom: 12,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'co.yaviene.control',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          left: 18,
          bottom: 18,
          child: _Legend(
            online: fleet.buses.values
                .where((b) => b.online && b.visible)
                .length,
            hidden: fleet.buses.values.where((b) => !b.visible).length,
            offline: fleet.buses.values.where((b) => !b.online).length,
          ),
        ),
      ],
    );
  }

  Marker _buildMarker(FleetBus bus, bool selected, VoidCallback onTap) {
    final (color, hidden) = switch ((bus.visible, bus.online, bus.isGhost)) {
      (false, _, _) => (AppColors.hidden, true),
      (_, false, _) => (AppColors.offline, true),
      (_, _, true) => (AppColors.ghost, false),
      _ => (AppColors.online, false),
    };
    return Marker(
      point: LatLng(bus.lat!, bus.lon!),
      width: 62,
      height: 62,
      child: GestureDetector(
        onTap: onTap,
        child: _BusMarker(
          busId: bus.busId,
          color: color,
          hidden: hidden,
          selected: selected,
        ),
      ),
    );
  }
}

class _BusMarker extends StatelessWidget {
  const _BusMarker({
    required this.busId,
    required this.color,
    required this.hidden,
    required this.selected,
  });

  final String busId;
  final Color color;
  final bool hidden;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: hidden ? Colors.white : color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? AppColors.navy
                  : hidden
                  ? color
                  : Colors.white,
              width: selected ? 2.5 : 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? AppColors.navy : color).withValues(
                  alpha: hidden ? 0.25 : 0.35,
                ),
                blurRadius: selected ? 14 : 8,
                spreadRadius: selected ? 1 : 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.directions_bus,
            size: 17,
            color: hidden ? color : const Color(0xFF0C0C0F),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: selected ? AppColors.navy : AppColors.borderStrong,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            busId,
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.online,
    required this.hidden,
    required this.offline,
  });

  final int online;
  final int hidden;
  final int offline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LEYENDA',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          _legendRow(AppColors.online, 'Visibles en línea', online),
          _legendRow(AppColors.hidden, 'Ocultos', hidden),
          _legendRow(AppColors.offline, 'Sin señal', offline),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 5),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
