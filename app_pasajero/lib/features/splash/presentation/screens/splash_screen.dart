import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/providers/app_state.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/ink_hero.dart';
import '../../../../core/widgets/live_route_backdrop.dart';
import '../../../onboarding/onboarding_flow.dart';

/// Pantalla de arranque: deja el estado de la sesión anterior limpio, muestra
/// la marca un momento y sigue a la bienvenida (primera vez) o al mapa. No
/// hay cuenta que esperar: el pasajero entra sin iniciar sesión.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Post-frame: resetTransientState modifica providers y Riverpod lo prohíbe
    // durante el build (initState). Diferido, el arranque queda limpio sin
    // la excepción de debug "Tried to modify a provider while building".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    // Arranque limpio pero NO destructivo: se quita estado efímero en memoria
    // (selecciones, avisos, sockets) y se conserva el pin manual guardado,
    // que es lo único que sobrevive al reabrir la app (la ruta se vuelve a
    // elegir cada vez). El pin solo se borra cuando el usuario lo quita.
    await resetTransientState(ref);
    // Tiempo mínimo de marca para que se vea el logo con calma.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await goToHome(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: LiveRouteBackdrop(
        // Aquí la marca va centrada, no arriba: el halo la sigue.
        haloY: 0.46,
        child: Center(
          // La marca no aparece de golpe: sube un poco y se funde, y el
          // indicador de carga entra después, cuando ya se leyó el nombre.
          // El splash dura 900 ms como mínimo, así que la entrada termina
          // con margen antes de que se cambie de pantalla.
          child: ScreenEntrance(
            // El logo NO entra: ya está en pantalla. La pantalla de arranque
            // nativa lo dibuja en este mismo sitio y a este mismo tamaño
            // (`LaunchScreen.storyboard`, 84 pt a -72,5 del centro), así que
            // fundirlo desde cero convertiría el relevo en un parpadeo. Lo
            // que entra es lo que la pantalla nativa no puede dibujar.
            builder: (context, entra) => InkHero(
              logoSize: 84,
              spacingAfterLogo: 20,
              entradaEscalonada: entra,
              trailing: entra(
                const IndicadorCarga(
                  size: 26,
                  color: Color.fromRGBO(255, 255, 255, 0.75),
                  // Es la única pieza de esta pantalla que dice que algo
                  // está pasando. Sin rótulo, el arranque es la marca y
                  // un silencio.
                  semanticsLabel: 'Abriendo Ya Viene',
                ),
                start: 0.55,
                begin: Offset.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
