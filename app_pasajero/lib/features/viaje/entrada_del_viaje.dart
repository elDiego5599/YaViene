import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/pildora_estado.dart';
import '../map/presentation/providers/selected_buses_provider.dart';

/// La puerta al planificador, en la misma columna de píldoras del mapa.
///
/// Con un bus tocado se va, como la de tu punto: ahí la persona ya sabe
/// qué bus quiere, y una píldora más solo tapa el mapa que está mirando.
class EntradaDelViaje extends ConsumerWidget {
  const EntradaDelViaje({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conBus = ref.watch(selectedBusesProvider).isNotEmpty;
    return AnimatedSwitcher(
      duration: AppMotion.duracion(context, AppMotion.normal),
      switchInCurve: AppMotion.curvaCambio,
      switchOutCurve: AppMotion.curvaCambio,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: conBus
          ? const SizedBox.shrink(key: ValueKey('sin-entrada'))
          : Padding(
              key: const ValueKey('entrada-viaje'),
              padding: const EdgeInsets.only(top: 8),
              child: PildoraEstado(
                data: PildoraDatos(
                  key: 'viaje',
                  icon: Icons.directions_rounded,
                  iconColor: AppColors.primaryAccessible,
                  tint: AppColors.primaryTint,
                  text: '¿A dónde vas?',
                  sub: 'Te decimos qué buses tomar',
                  actionLabel: 'Planear',
                  onAction: () => context.push(AppRoutes.viaje),
                ),
              ),
            ),
    );
  }
}
