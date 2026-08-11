import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fleet_bus.dart';
import '../providers/fleet_providers.dart';

class ControlMap extends ConsumerStatefulWidget {
  const ControlMap({super.key});

  @override
  ConsumerState<ControlMap> createState() => _ControlMapState();
}

class _ControlMapState extends ConsumerState<ControlMap> {
  final MapController _mapController = MapController();
  double _zoom = 12;

  double get _markerSize => (16 + (_zoom - 11) * 4).clamp(16.0, 32.0);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  static bool _inRoute(FleetState fleet, FleetBus bus) =>
      fleet.routeFilter == null || bus.routeId == fleet.routeFilter;

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(fleetProvider);
    final size = _markerSize;
    final markers = fleet.fleetList
        .where((b) => b.visible && b.lat != null && b.lon != null)
        .map(
          (b) => _buildMarker(b, fleet.selectedBusId == b.busId, size, () {
            ref.read(fleetProvider.notifier).selectBus(b.busId);
          }),
        )
        .toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(10.9639, -74.7964),
            initialZoom: 12,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: (camera, hasGesture) {
              if ((camera.zoom - _zoom).abs() > 0.05) {
                setState(() => _zoom = camera.zoom);
              }
            },
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
            // La leyenda describe lo que se ve en el mapa: escopado a la ruta
            // seleccionada como las pestañas y los marcadores (antes contaba
            // toda la empresa y los números no coincidían con nada).
            online: fleet.buses.values
                .where((b) =>
                    _inRoute(fleet, b) && b.online && b.visible && !b.isGhost)
                .length,
            hidden: fleet.buses.values
                .where((b) => _inRoute(fleet, b) && !b.visible)
                .length,
            offline: fleet.buses.values
                .where((b) => _inRoute(fleet, b) && (!b.online || b.isGhost))
                .length,
          ),
        ),
      ],
    );
  }

  Marker _buildMarker(
    FleetBus bus,
    bool selected,
    double size,
    VoidCallback onTap,
  ) {
    return Marker(
      point: LatLng(bus.lat!, bus.lon!),
      width: size,
      height: size,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Transform.rotate(
          angle: bus.heading * math.pi / 180,
          child: CustomPaint(
            size: Size.square(size),
            painter: _FlatBusPainter(
              active: bus.online && !bus.isGhost,
              selected: selected,
            ),
          ),
        ),
      ),
    );
  }
}

class _FlatBusPainter extends CustomPainter {
  const _FlatBusPainter({required this.active, required this.selected});

  final bool active;
  final bool selected;

  static const Color _activeBody = Color(0xFF14274E);
  static const Color _ghostBody = Color(0xFF94A3B8);
  static const Color _headlight = Color(0xFF00A859);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 80;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final baseColor = active ? _activeBody : _ghostBody;

    if (selected) {
      final halo = Paint()
        ..color = _headlight.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * s);
      canvas.drawCircle(Offset(centerX, centerY), 24 * s, halo);
    }

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(centerX, centerY), width: 32 * s, height: 60 * s),
      const Radius.circular(10),
    );

    canvas.drawShadow(
      (ui.Path()
        ..addRect(
          Rect.fromCenter(
            center: Offset(centerX, centerY + 2 * s),
            width: 32 * s,
            height: 60 * s,
          ),
        )),
      Colors.black.withValues(alpha: 0.15),
      4.0 * s,
      false,
    );

    canvas.drawRRect(bodyRect, Paint()..color = baseColor);

    final glassRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY - 18 * s),
        width: 24 * s,
        height: 10 * s,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      glassRect,
      Paint()..color = Colors.white.withValues(alpha: active ? 0.95 : 0.5),
    );

    if (active) {
      final light = Paint()..color = _headlight;
      canvas.drawCircle(Offset(centerX - 8 * s, centerY + 24 * s), 3 * s, light);
      canvas.drawCircle(Offset(centerX + 8 * s, centerY + 24 * s), 3 * s, light);
    }
  }

  @override
  bool shouldRepaint(_FlatBusPainter oldDelegate) =>
      oldDelegate.active != active || oldDelegate.selected != selected;
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
          _legendRow(AppColors.online, 'En línea', online),
          _legendRow(AppColors.offline, 'Sin señal', offline),
          _legendRow(AppColors.textMuted, 'Ocultos (no se muestran)', hidden),
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
