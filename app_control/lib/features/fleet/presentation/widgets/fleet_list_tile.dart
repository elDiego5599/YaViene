import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fleet_bus.dart';
import '../bus_estado.dart';

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
  });

  final FleetBus bus;
  final bool selected;
  final bool updating;
  final String? routeName;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final estado = BusEstado.de(bus);
    final card = Material(
      // Seleccionado = el mismo azul del halo en el mapa. Antes era un verde
      // tenue suelto, que además chocaba con el verde de "en línea": una fila
      // en línea y sin seleccionar se veía casi igual que una seleccionada.
      color: selected
          ? Color.alphaBlend(
              AppColors.selection.withValues(alpha: 0.07),
              AppColors.surface,
            )
          : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected
                  ? AppColors.selection.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              // El recuadro sigue siendo un bus: dice qué es esta fila. Lo que
              // dice en qué situación está es el ícono de al lado del nombre.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: estado.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.directions_bus,
                  size: 20,
                  color: estado.color,
                ),
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
                          style: AppType.ui(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Era un punto de 6 px: cuatro situaciones distintas
                        // con la misma forma, y quien no separa verde de
                        // ámbar veía cuatro filas idénticas. El ícono dice
                        // cuál es sin leer el color, y el tooltip lo explica
                        // con palabras (antes solo conocía dos casos).
                        Tooltip(
                          message: _explicacion(estado),
                          child: Icon(
                            estado.icono,
                            size: 14,
                            color: estado.color,
                            semanticLabel: estado.rotulo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (bus.driverName != null)
                          Flexible(
                            child: Text(
                              bus.driverName!,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.ui(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
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
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    routeName!,
                    style: AppType.ui(
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
              const SizedBox(width: 2),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      : Tooltip(
                          message: bus.visible
                              ? 'Los pasajeros pueden ver este bus'
                              : 'Oculto para los pasajeros',
                          child: Switch(
                            value: bus.visible,
                            onChanged: (v) => onToggle(v),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                  const SizedBox(height: 2),
                  Text(
                    bus.visible ? 'PERMITIDO' : 'OCULTO',
                    style: AppType.ui(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: bus.visible ? AppColors.online : AppColors.hidden,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Opacity(opacity: bus.online ? 1 : 0.7, child: card);
  }

  /// Qué significa el estado, en la frase que el operador necesita: qué pasa
  /// y si tiene que hacer algo.
  String _explicacion(BusEstado estado) => switch (estado) {
        BusEstado.enLinea => 'En línea: el bus está transmitiendo',
        BusEstado.inactivo =>
          'Inactivo: lleva más de 90 s sin reportar, pero el turno sigue abierto',
        BusEstado.sinSenal => 'Sin señal: el bus no está transmitiendo',
        BusEstado.oculto => 'Oculto: lo quitaste del mapa de los pasajeros',
      };
}
