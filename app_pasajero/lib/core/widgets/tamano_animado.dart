import 'package:flutter/widgets.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// `AnimatedSize` que obedece «Reducir movimiento».
///
/// A duración cero, `AnimatedSize` no salta al tamaño nuevo: su
/// controlador termina en el mismo layout que lo arrancó, avisa, y el
/// render se vuelve a ensuciar mientras se mide («A RenderAnimatedSize
/// was mutated in its own performLayout»). Sin movimiento no hay nada que
/// animar: el hijo va tal cual, con su tamaño.
class TamanoAnimado extends StatelessWidget {
  const TamanoAnimado({
    super.key,
    required this.duracion,
    required this.child,
    this.curva = AppMotion.curvaCambio,
    this.alineacion = Alignment.center,
  });

  /// La duración con movimiento; con menos movimiento no se usa.
  final Duration duracion;
  final Curve curva;
  final AlignmentGeometry alineacion;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppMotion.reducido(context)
      ? child
      : AnimatedSize(
          duration: duracion,
          curve: curva,
          alignment: alineacion,
          child: child,
        );
}
