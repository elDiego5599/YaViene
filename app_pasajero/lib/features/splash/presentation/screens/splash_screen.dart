import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_state.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/map_pattern_painter.dart';
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
    final session =
        auth.sessionResolved.timeout(const Duration(seconds: 6), onTimeout: () {});
    await Future.wait([session, minBranding]);
    if (!mounted) return;
    if (auth.state.status == AuthStatus.verified) {
      await goToHome(context);
    } else {
      context.replace('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14274E),
      body: CustomPaint(
        painter: const MapPatternPainter(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00A859).withValues(alpha: 0.35),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/icon/ya_viene_logo.svg',
                  width: 84,
                  height: 84,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ya Viene',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tu ciudad en tiempo real.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.75),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
