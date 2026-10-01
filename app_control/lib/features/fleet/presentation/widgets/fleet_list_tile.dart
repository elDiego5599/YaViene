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
        // Plana: la fila era una tarjeta con borde dentro de la tarjeta con
        // borde de la lista, y los bordes apilados se leían como ruido. Solo
        // la elegida lleva marco. El de las demás sigue ahí, transparente,
        // para que elegir una fila no la mueva un píxel.
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected
                  ? AppColors.selection.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // El recuadro sigue siendo un bus: dice qué es esta fila. Lo que
              // dice en qué situación está es el ícono de al lado del nombre.
              // 36, el recuadro de la ficha del bus: sin el borde de la
              // tarjeta alrededor, el de 40 pesaba más que la placa.
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: estado.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.directions_bus,
                  size: 19,
                  color: estado.color,
                ),
              ),
              const SizedBox(width: 12),
              // La fila es la placa y su estado, nada más. Llevaba también un
              // chip con la ruta y un renglón con el conductor: el chip no
              // cabía (en 1440 ni se pintaba y en 1600 salía cortado) y el
              // conductor de la flota de ejemplo, «Conductor 3001», no le
              // decía nada al operador. La ruta ya la dice la pestaña de
              // arriba, y la ficha del bus la repite entera.
              //
              // Un lector de pantalla oye la fila como una frase
              // ([_frase]) en vez del ícono suelto.
              Expanded(
                child: Semantics(
                  label: _frase(estado),
                  selected: selected,
                  child: ExcludeSemantics(
                    // Si la placa no cabe a su tamaño, que con la ventana
                    // maximizada no pasa ni a 1280 pero sí achicándola a
                    // mano, se achica lo justo: cortada ya no diría qué bus
                    // es.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                          // con palabras.
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
                    ),
                  ),
                ),
              ),
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
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                  const SizedBox(height: 2),
                  // El interruptor ya dice su estado y su tooltip lo explica.
                  // A 9 y no a 8, que en un proyector no se leía; el
                  // espaciado baja de 1,2 a 0,8 para que «PERMITIDO» mida
                  // casi lo mismo y no le quite sitio a la placa
                  // (fleet_list_tile_test.dart).
                  ExcludeSemantics(
                    child: Text(
                      bus.visible ? 'PERMITIDO' : 'OCULTO',
                      style: AppType.ui(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: bus.visible
                            ? AppColors.online
                            : AppColors.hidden,
                      ),
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

  /// La fila dicha en voz alta: «Placa ABC123, En línea, ruta Tcherassi».
  /// La ruta no se ve en la fila pero se dice: quien no ve la pantalla
  /// tampoco ve la pestaña de arriba.
  String _frase(BusEstado estado) => [
    bus.placa.isEmpty ? 'Bus ${bus.busId}' : 'Placa ${bus.placa}',
    estado.rotulo,
    if (routeName != null) 'ruta $routeName',
  ].join(', ');

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
