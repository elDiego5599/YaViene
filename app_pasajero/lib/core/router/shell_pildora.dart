import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../features/map/presentation/providers/active_alerts_provider.dart';
import '../../features/map/presentation/providers/map_tour_provider.dart';
import '../widgets/pildora_navegacion.dart';

/// Las cuatro pestañas con la píldora flotando abajo.
///
/// No es el `bottomNavigationBar` de un Scaffold: con `extendBody`, el
/// Scaffold sube el relleno de abajo al alto de la barra aunque haya
/// teclado, y el buzón quedaba con un hueco encima del teclado. Aquí la
/// píldora va encima y las pestañas reciben su alto como relleno de abajo:
/// cada pantalla, con su `SafeArea`, termina sobre la píldora, y lo que
/// pinta de fondo (el mapa, la hoja) sigue por debajo hasta el borde.
class ShellConPildora extends ConsumerWidget {
  const ShellConPildora({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Lo que la píldora le quita a la pantalla por abajo: su hueco sobre el
  /// borde, ella misma y un respiro de 8 para que nada la roce.
  static double reserva(EdgeInsets viewPadding) =>
      _hueco(viewPadding) + PildoraNavegacion.alto + AppSpacing.sm;

  /// Con barra de inicio (34 en iPhone) la píldora se apoya 22 sobre el
  /// borde, encima de la barra y sin taparla; sin ella, 12.
  static double _hueco(EdgeInsets viewPadding) =>
      math.max(viewPadding.bottom - 12, 12);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guia = ref.watch(mapGuideProvider);
    final avisos = ref.watch(activeAlertsProvider).length;
    final media = MediaQuery.of(context);
    // La guía y la bienvenida tienen su velo y su botón abajo: la barra se
    // aparta para no competir con ellos ni dejar salir a medias. Con el
    // teclado arriba tampoco cabe: lo que se escribe manda.
    final oculta =
        guia.isActive || guia.bienvenida || media.viewInsets.bottom > 0;
    final reserva = ShellConPildora.reserva(media.viewPadding);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: oculta ? 0 : 1),
      duration: AppMotion.duracion(context, AppMotion.normal),
      curve: AppMotion.curvaCambio,
      builder: (context, t, _) {
        final abajo =
            media.padding.bottom + (reserva - media.padding.bottom) * t;
        return Stack(
          children: [
            Positioned.fill(
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(bottom: abajo),
                ),
                child: navigationShell,
              ),
            ),
            if (t > 0)
              Positioned(
                left: 20,
                right: 20,
                bottom: _hueco(media.viewPadding),
                child: IgnorePointer(
                  ignoring: oculta,
                  child: ExcludeSemantics(
                    excluding: oculta,
                    child: Opacity(
                      opacity: t,
                      child: Transform.translate(
                        // Baja por donde sube: se va hacia el borde, de donde
                        // vino.
                        offset: Offset(
                            0,
                            reserva *
                                (1 - t) *
                                AppMotion.desplazamiento(context)),
                        child: PildoraNavegacion(
                          indice: navigationShell.currentIndex,
                          avisosActivos: avisos,
                          alElegir: (i) => navigationShell.goBranch(i),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
