import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/providers/app_state.dart';
import '../../../../core/widgets/fondo_texturizado.dart';
import '../../../onboarding/onboarding_flow.dart';
import '../widgets/escena_arranque.dart';

/// Pantalla de arranque: deja el estado de la sesión anterior limpio, pinta
/// la escena de Barranquilla con la marca ([EscenaArranque]) y sigue a la
/// bienvenida (primera vez) o al mapa. No hay cuenta que esperar: el
/// pasajero entra sin iniciar sesión.
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

  /// Se completa cuando la escena quedó armada.
  final _escena = Completer<void>();

  Future<void> _start() async {
    // Arranque limpio pero NO destructivo: se quita estado efímero en memoria
    // (selecciones, avisos, sockets) y se conserva el pin manual guardado,
    // que es lo único que sobrevive al reabrir la app (la ruta se vuelve a
    // elegir cada vez). El pin solo se borra cuando el usuario lo quita.
    // Se sigue cuando están las dos cosas: el estado limpio y la escena
    // entera (dueño, 2026-10-18: breve, pero que se vea completa).
    await Future.wait([resetTransientState(ref), _escena.future]);
    if (!mounted) return;
    await goToHome(context);
  }

  @override
  Widget build(BuildContext context) {
    // El blanco texturizado conserva el relevo visual con el arranque nativo.
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FondoTexturizado(),
          Center(
            child: EscenaArranque(
              alTerminar: () {
                if (!_escena.isCompleted) _escena.complete();
              },
            ),
          ),
        ],
      ),
    );
  }
}
