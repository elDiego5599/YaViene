import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// El asa de una hoja: la marca de que ahí se puede poner el dedo.
///
/// Había dos, y se veían una detrás de otra —la del selector encima de la de
/// distancia— con anchos y colores distintos sin ninguna razón. Ahora es una
/// sola, y la diferencia que sí importa se pide con [abierta].
///
/// Con [abierta] en 1 el asa está en reposo: estrecha y clara, porque la
/// hoja ya está abierta y no hay nada que anunciar. Al bajar hacia 0 se
/// ensancha y se oscurece: es la señal de que queda algo que volver a abrir,
/// y se ve venir durante el arrastre en vez de aparecer al soltar.
///
/// Quien no se pliegue —el selector, que se va entero— la deja en 1 y ya.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.abierta = 1.0});

  /// 1 = hoja abierta, 0 = plegada.
  final double abierta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 56 - 12 * abierta,
        height: 5,
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.textDisabled,
            AppColors.divider,
            abierta,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}
