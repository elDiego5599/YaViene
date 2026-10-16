import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// El borde de desplazamiento de iOS, sin vidrio: lo que sube bajo un
/// título fijo se disuelve en una franja corta en vez de cortarse en seco
/// contra él (dueño, 2026-10-16: «que la parte de arriba se pueda ver el
/// fondo»). Debajo de la franja el contenido queda entero, así que quien
/// lo use deja arriba al menos [alto] de relleno: en reposo no se funde
/// nada.
class BordeDesvanecido extends StatelessWidget {
  const BordeDesvanecido({super.key, required this.child});

  /// La franja que se funde. Corta: la justa para que el corte no se vea y
  /// sin comerse una fila de texto.
  static const double alto = 16;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      // `dstIn` deja del contenido solo lo que el degradado tapa: nada en
      // el filo de arriba, todo pasada la franja.
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00000000), Color(0xFF000000)],
        stops: [0, math.min(1, alto / r.height)],
      ).createShader(r),
      child: child,
    );
  }
}
