import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fleet_bus.dart';

class FleetListTile extends StatelessWidget {
  const FleetListTile({
    super.key,
    required this.bus,
    required this.selected,
    required this.updating,
    required this.routeName,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final FleetBus bus;
  final bool selected;
  final bool updating;
  final String? routeName;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _status(bus);
    return Material(
      color: selected ? const Color(0xFFF1F6F2) : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.online.withValues(alpha: 0.5) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.directions_bus, size: 20, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          bus.placa.isEmpty ? bus.busId : bus.placa,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            bus.busId,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (bus.driverName != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '· ${bus.driverName}',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (routeName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    routeName!,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 17,
                  color: AppColors.textMuted,
                ),
                tooltip: 'Editar bus',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 17,
                  color: AppColors.textMuted,
                ),
                tooltip: 'Eliminar bus',
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 2),
              updating
                  ? const SizedBox(
                      width: 36,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Switch(
                      value: bus.visible,
                      onChanged: (v) => onToggle(v),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color) _status(FleetBus bus) {
    if (!bus.online) return ('Sin señal', AppColors.offline);
    if (bus.isGhost) return ('Inactivo', AppColors.ghost);
    return ('En línea', AppColors.online);
  }
}
