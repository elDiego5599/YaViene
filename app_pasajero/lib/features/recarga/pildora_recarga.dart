import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../core/widgets/pildora_estado.dart';
import 'recarga_providers.dart';

/// Lo que la capa de recarga tiene que decir, en la misma píldora que la de
/// tu punto: cuántos hay cerca, que no hay ninguno o que el archivo falló.
///
/// Apagada, cargando o sin punto de la persona no dice nada: el mapa ya lo
/// enseña, y una píldora más sobre el mapa solo tapa.
class PildoraRecarga extends ConsumerWidget {
  const PildoraRecarga({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pildora = switch (ref.watch(estadoRecargaProvider)) {
      RecargaApagada() || RecargaCargando() || RecargaSinPunto() => null,
      RecargaError() => PildoraDatos(
          key: 'recarga-error',
          icon: Icons.error_outline,
          iconColor: AppColors.warningAccessible,
          tint: AppColors.warningLight,
          text: 'No se pudieron leer los puntos de recarga',
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(puntosRecargaProvider),
          vivo: true,
        ),
      RecargaCerca(cercanos: []) => const PildoraDatos(
          key: 'recarga-vacia',
          icon: Icons.add_card_outlined,
          iconColor: AppColors.warningAccessible,
          tint: AppColors.warningLight,
          text: 'No hay puntos de recarga cerca',
          vivo: true,
        ),
      RecargaCerca(:final cercanos) => PildoraDatos(
          key: 'recarga-cerca',
          icon: Icons.add_card_outlined,
          iconColor: AppColors.primaryAccessible,
          tint: AppColors.primaryTint,
          text: textoPuntosCerca(cercanos.length),
          vivo: true,
        ),
    };

    return AnimatedSwitcher(
      duration: AppMotion.duracion(context, AppMotion.normal),
      switchInCurve: AppMotion.curvaEntrada,
      switchOutCurve: AppMotion.curvaSalida,
      // Sube desde los botones de abajo, de donde se prendió.
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (actual, anteriores) => Stack(
        alignment: Alignment.bottomRight,
        children: [...anteriores, if (actual != null) actual],
      ),
      child: pildora == null
          ? const SizedBox.shrink(key: ValueKey('sin-pildora-recarga'))
          : KeyedSubtree(
              key: ValueKey(pildora.key),
              child: PildoraEstado(data: pildora),
            ),
    );
  }
}
