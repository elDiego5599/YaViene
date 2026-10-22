import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../features/map/presentation/providers/active_alerts_provider.dart';
import '../../features/map/presentation/providers/map_tour_provider.dart';
import '../../features/map/presentation/providers/map_view_state.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../widgets/aviso.dart';
import '../widgets/pildora_navegacion.dart';

/// Las cuatro pestañas con la píldora flotando abajo.
///
/// No es el `bottomNavigationBar` de un Scaffold: con `extendBody`, el
/// Scaffold sube el relleno de abajo al alto de la barra aunque haya
/// teclado, y el buzón quedaba con un hueco encima del teclado. Aquí la
/// píldora va encima y las pestañas reciben su alto como relleno de abajo:
/// cada pantalla, con su `SafeArea`, termina sobre la píldora, y lo que
/// pinta de fondo (el mapa, la hoja) sigue por debajo hasta el borde.
class ShellConPildora extends ConsumerStatefulWidget {
  const ShellConPildora({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Lo que la píldora le quita a la pantalla por abajo: su hueco sobre el
  /// borde, ella misma y un respiro de 8 para que nada la roce.
  static double reserva(EdgeInsets viewPadding) =>
      PildoraNavegacion.hueco(viewPadding) +
      PildoraNavegacion.alto +
      AppSpacing.sm;

  @override
  ConsumerState<ShellConPildora> createState() => _ShellConPildoraState();
}

class _ShellConPildoraState extends ConsumerState<ShellConPildora> {
  late int _indiceAnterior = widget.navigationShell.currentIndex;

  @override
  void didUpdateWidget(ShellConPildora oldWidget) {
    super.didUpdateWidget(oldWidget);
    final actual = widget.navigationShell.currentIndex;
    if (avisoDebeDesaparecerAlCambiarPestana(_indiceAnterior, actual)) {
      // El ScaffoldMessenger es compartido por las ramas del shell. Cerrar
      // aquí el aviso evita que el «Deshacer» de una pestaña sobreviva en otra.
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    }
    _indiceAnterior = actual;
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final ref = this.ref;
    final guia = ref.watch(mapGuideProvider);
    final avisos = ref.watch(activeAlertsProvider).length;
    final media = MediaQuery.of(context);
    // La guía y la bienvenida tienen su velo y su botón abajo: la barra se
    // aparta para no competir con ellos ni dejar salir a medias. Con el
    // teclado arriba tampoco cabe: lo que se escribe manda. Ni con la rueda
    // de la distancia, que se contesta antes de irse.
    final oculta = guia.isActive ||
        guia.bienvenida ||
        media.viewInsets.bottom > 0 ||
        ref.watch(eligiendoDistanciaProvider) ||
        // Seleccionando avisos, su botón de borrar ocupa el sitio de la
        // barra, como en Fotos (dueño, 2026-10-16: se solapaban). Solo se
        // escucha en Avisos: fuera, la selección se olvida (`autoDispose`).
        (navigationShell.currentIndex == 1 &&
            ref.watch(alertSelectionProvider).active);
    final reserva = ShellConPildora.reserva(media.viewPadding);
    // En el mapa la hoja crece de la barra (dueño, 2026-10-16): la barra
    // le cede fondo, filo y sombra. Con el selector arriba la hoja se
    // aparta, y la barra vuelve a ser la suya.
    final fundida = navigationShell.currentIndex == 0 &&
        !ref.watch(routeSelectorOpenProvider);

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
                child: PildoraVisible(visible: t, child: navigationShell),
              ),
            ),
            if (t > 0)
              Positioned(
                left: PildoraNavegacion.lado,
                right: PildoraNavegacion.lado,
                bottom: PildoraNavegacion.hueco(media.viewPadding),
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
                          fundida: fundida,
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
