import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// El grupo flotante de arriba —búsqueda, ubicación, conexión— cuando el
/// selector de ruta ocupa la pantalla.
///
/// Es el gesto en espejo de la hoja de distancia: aquella se hunde, esta se
/// levanta, las dos por el borde por el que ya estaban asomadas. Que las dos
/// se aparten a la vez es lo que deja el mapa limpio detrás del selector, en
/// vez de una tarjeta encima de una app dibujada a media luz.
class CabeceraFlotante extends StatelessWidget {
  const CabeceraFlotante({
    super.key,
    required this.apartada,
    required this.child,
  });

  final bool apartada;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final paso = AppMotion.duracion(context, AppMotion.pausado);
    return IgnorePointer(
      ignoring: apartada,
      child: AnimatedSlide(
        offset: apartada ? const Offset(0, -0.4) : Offset.zero,
        duration: paso,
        curve: apartada ? AppMotion.curvaSalida : AppMotion.curvaEntrada,
        child: AnimatedOpacity(
          opacity: apartada ? 0 : 1,
          duration: paso,
          curve: apartada ? AppMotion.curvaSalida : AppMotion.curvaEntrada,
          child: child,
        ),
      ),
    );
  }
}
