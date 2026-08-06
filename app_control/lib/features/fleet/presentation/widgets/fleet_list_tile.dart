import 'package:flutter/material.dart';

import '../../domain/fleet_bus.dart';

class FleetListTile extends StatelessWidget {
  const FleetListTile({
    super.key,
    required this.bus,
    required this.updating,
    required this.onToggle,
  });

  final FleetBus bus;
  final bool updating;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final statusColor = !bus.online
        ? const Color(0xFF64748B)
        : bus.isGhost
            ? const Color(0xFF94A3B8)
            : const Color(0xFF00A859);
    final statusLabel = !bus.online
        ? 'Sin señal'
        : bus.isGhost
            ? 'Inactivo'
            : 'En línea';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(Icons.directions_bus, size: 20, color: statusColor),
        ),
        title: Text(
          bus.busId,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${bus.routeId ?? 'Sin ruta'} · $statusLabel',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: updating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(
                value: bus.visible,
                onChanged: (bus.online) ? onToggle : null,
              ),
      ),
    );
  }
}
