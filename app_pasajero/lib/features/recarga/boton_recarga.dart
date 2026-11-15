import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../map/presentation/providers/map_view_state.dart';
import '../map/presentation/providers/user_location_provider.dart';
import 'recarga_providers.dart';

/// Prende y apaga la capa de puntos de recarga.
///
/// Es hermano del botón de volver a tu punto: mismo círculo de 48 pt (el
/// toque mínimo de Apple), mismo filo y misma sombra, a su lado. Como el
/// selector de capas de Apple Maps, prendido se llena: en el azul de los
/// botones, con el glifo en blanco (7,1:1), y entra con el rebote de lo que
/// se acaba de marcar.
class BotonRecarga extends ConsumerWidget {
  const BotonRecarga({super.key});

  static const double _lado = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prendida = ref.watch(capaRecargaVisibleProvider);
    // Los puntos se cuentan desde el pin: sin pin puesto no hay «cerca» y el
    // botón sobra. Si la capa ya está prendida se queda, para poder apagarla.
    final conPin = ref.watch(userLocationProvider.select((u) => u.hasPosition));
    // Con el selector encima o el mapa a medio pintar no hay mapa en el que
    // prender nada: se va, como el de volver a tu punto.
    final visible = (conPin || prendida) &&
        !ref.watch(routeSelectorOpenProvider) &&
        !ref.watch(mapPreparingProvider);
    final rapido = AppMotion.duracion(context, AppMotion.rapido);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedScale(
        scale: visible ? 1 : 0.85,
        duration: rapido,
        curve: visible ? AppMotion.curvaEntrada : AppMotion.curvaSalida,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: rapido,
          curve: visible ? AppMotion.curvaEntrada : AppMotion.curvaSalida,
          child: Semantics(
            button: true,
            toggled: prendida,
            label: 'Puntos de recarga',
            excludeSemantics: true,
            onTap: () => _alternar(ref),
            child: AnimatedContainer(
              width: _lado,
              height: _lado,
              duration: AppMotion.duracion(context, AppMotion.normal),
              curve: AppMotion.curvaCambio,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: prendida
                    ? AppColors.acento
                    : Colors.white.withValues(alpha: 0.96),
                border: Border.all(
                  color: prendida ? AppColors.acento : AppColors.divider,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDeep.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _alternar(ref),
                  child: Center(
                    // Al prenderse el glifo rebota un poco, la seña de que
                    // algo quedó marcado; al apagarse vuelve sin rebote.
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(prendida),
                      tween: Tween(begin: prendida ? 0.8 : 1, end: 1),
                      duration: AppMotion.duracion(context, AppMotion.normal),
                      curve: AppMotion.curvaRebote,
                      builder: (context, escala, glifo) =>
                          Transform.scale(scale: escala, child: glifo),
                      child: Icon(
                        Icons.add_card_outlined,
                        size: 22,
                        color: prendida
                            ? Colors.white
                            : AppColors.primaryAccessible,
                      ),
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

  void _alternar(WidgetRef ref) =>
      ref.read(capaRecargaVisibleProvider.notifier).update((v) => !v);
}
