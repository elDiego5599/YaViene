import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/fleet_providers.dart';

class ControlMap extends ConsumerWidget {
  const ControlMap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleet = ref.watch(fleetProvider);
    final markers = fleet.fleetList
        .where((b) => b.lat != null && b.lon != null)
        .map((b) => _buildMarker(b))
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
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'co.yaviene.control',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: _Legend(
            online: fleet.buses.values.where((b) => b.online && b.visible).length,
            ghost: fleet.buses.values.where((b) => b.online && !b.visible).length,
            offline: fleet.buses.values.where((b) => !b.online).length,
          ),
        ),
      ],
    );
  }

  Marker _buildMarker(dynamic bus) {
    final Color color;
    final bool hidden;
    if (!bus.visible) {
      color = const Color(0xFF94A3B8);
      hidden = true;
    } else if (bus.isGhost) {
      color = const Color(0xFF64748B);
      hidden = false;
    } else {
      color = const Color(0xFF00A859);
      hidden = false;
    }
    return Marker(
      point: LatLng(bus.lat, bus.lon),
      width: 36,
      height: 36,
      child: _BusMarker(busId: bus.busId, color: color, hidden: hidden),
    );
  }
}

class _BusMarker extends StatelessWidget {
  const _BusMarker({required this.busId, required this.color, required this.hidden});

  final String busId;
  final Color color;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: hidden ? Colors.white : color,
            shape: BoxShape.circle,
            border: Border.all(
              color: hidden ? const Color(0xFF94A3B8) : Colors.white,
              width: hidden ? 2 : 1.5,
            ),
            boxShadow: hidden
                ? null
                : const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
          ),
          child: Icon(
            Icons.directions_bus,
            size: 16,
            color: hidden ? const Color(0xFF94A3B8) : Colors.white,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
          ),
          child: Text(
            busId,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.online,
    required this.ghost,
    required this.offline,
  });

  final int online;
  final int ghost;
  final int offline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendRow(const Color(0xFF00A859), 'Visibles en línea ($online)'),
          _legendRow(const Color(0xFF94A3B8), 'Ocultos ($ghost)'),
          _legendRow(const Color(0xFF64748B), 'Sin señal ($offline)'),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
