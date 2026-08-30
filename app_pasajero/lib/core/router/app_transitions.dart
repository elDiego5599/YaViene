import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Transición de pantalla suave tipo premium para toda la app: la nueva
/// pantalla entra con un leve deslizamiento lateral y fundido, en vez del
/// corte seco de Android por defecto.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeSlideTransition(animation: animation, child: child);
  }
}

/// Fundido + deslizamiento sobre una animación de ruta.
///
/// Vive en un widget propio porque su `CurvedAnimation` hay que desecharla, y
/// los constructores de transición (`buildTransitions`, `transitionBuilder`)
/// se llaman en cada construcción de la ruta: crearla ahí dejaba una suelta
/// —enganchada a la animación de la ruta— cada vez, y ninguna se soltaba.
class FadeSlideTransition extends StatefulWidget {
  const FadeSlideTransition({
    super.key,
    required this.animation,
    required this.child,
    this.begin = const Offset(0.06, 0),
  });

  final Animation<double> animation;
  final Widget child;

  /// Desde dónde entra, en fracciones del tamaño del hijo.
  final Offset begin;

  @override
  State<FadeSlideTransition> createState() => _FadeSlideTransitionState();
}

class _FadeSlideTransitionState extends State<FadeSlideTransition> {
  late CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _curved = _crear();
  }

  CurvedAnimation _crear() => CurvedAnimation(
        parent: widget.animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

  @override
  void didUpdateWidget(FadeSlideTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _curved.dispose();
      _curved = _crear();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // El fundido se queda incluso con movimiento reducido: lo que marea es
    // el desplazamiento. Sin fundido, el cambio de pantalla se lee como un
    // parpadeo roto.
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.begin * AppMotion.desplazamiento(context),
          end: Offset.zero,
        ).animate(_curved),
        child: widget.child,
      ),
    );
  }
}
