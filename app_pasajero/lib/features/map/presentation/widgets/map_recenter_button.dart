import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../providers/map_view_state.dart';
import '../providers/user_location_provider.dart';

/// El botón de volver a tu punto, en la esquina que dejó libre la atribución.
///
/// Sin él el encuadre automático era una trampa: lleva la cámara al punto de
/// espera una vez al elegir ruta y, en cuanto el usuario arrastra el mapa
/// —lo primero que hace cualquiera—, no había forma de regresar salvo cambiar
/// de ruta. Toda app de mapa del mundo tiene esta diana; la nuestra no.
class MapRecenterButton extends ConsumerWidget {
  const MapRecenterButton({super.key});

  static const double _lado = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ubicacion = ref.watch(userLocationProvider);
    final selectorAbierto = ref.watch(routeSelectorOpenProvider);
    final preparando = ref.watch(mapPreparingProvider);

    // Sin punto no hay a dónde volver, y con el mapa a medio pintar o el
    // selector encima no hay mapa que recentrar: el botón no se queda
    // apagado ocupando sitio, se va.
    final visible = ubicacion.hasPosition && !selectorAbierto && !preparando;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedScale(
        scale: visible ? 1 : 0.85,
        duration: AppMotion.duracion(context, AppMotion.rapido),
        curve: visible ? AppMotion.curvaEntrada : AppMotion.curvaSalida,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: AppMotion.duracion(context, AppMotion.rapido),
          curve: visible ? AppMotion.curvaEntrada : AppMotion.curvaSalida,
          child: Container(
            width: _lado,
            height: _lado,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.96),
              border: Border.all(color: AppColors.divider),
              // La misma sombra de las píldoras de arriba: los elementos que
              // flotan sobre el mapa flotan todos a la misma altura.
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDeep.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Semantics(
              button: true,
              label: 'Centrar el mapa en tu punto de espera',
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () =>
                      ref.read(mapRecenterRequestProvider.notifier).recenter(),
                  child: const Center(
                    child: Icon(
                      Icons.my_location_rounded,
                      size: 22,
                      color: AppColors.primaryAccessible,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
