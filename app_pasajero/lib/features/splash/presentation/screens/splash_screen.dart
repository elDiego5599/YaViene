import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/providers/app_state.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/ink_hero.dart';
import '../../../../core/widgets/live_route_backdrop.dart';
import '../../../onboarding/onboarding_flow.dart';

/// Pantalla de arranque: espera a que Firebase resuelva la sesión guardada
/// (o confirme que no hay) antes de ir al mapa o al inicio de sesión, para
/// que nunca se vea el login "parpadeando".
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
    // elegir cada sesión). El reseteo completo (con borrado del pin) es solo
    // para cerrar sesión.
    await resetTransientState(ref);
    final auth = ref.read(authProvider);
    // Tiempo mínimo de marca para que se vea el logo con calma.
    final minBranding = Future.delayed(const Duration(milliseconds: 900));
    // Red de seguridad: Firebase siempre emite su estado al arrancar, pero
    // si por cualquier razón no lo hiciera, no nos quedamos colgados.
    // F15: se distingue de "no hay sesión" para no dejar caer en el login
    // sin ninguna pista de que la verificación no llegó a completarse.
    var timedOut = false;
    final session = auth.sessionResolved.timeout(
      const Duration(seconds: 6),
      onTimeout: () => timedOut = true,
    );
    await Future.wait([session, minBranding]);
    if (!mounted) return;
    if (auth.state.status == AuthStatus.verified) {
      await goToHome(context);
    } else {
      context.replace(timedOut ? '/login?reason=timeout' : '/login');
    }
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
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color.fromRGBO(255, 255, 255, 0.6),
                  ),
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
