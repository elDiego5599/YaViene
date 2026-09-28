import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// La velocidad del bus seleccionado, en grande: «32 km/h». Es lo primero
/// que un operador busca al tocar un bus, y antes iba como nota al pie del
/// «Último reporte», en letra de 10,5 pt.
///
/// Sobria a propósito, como el resto del panel: una cifra de ancho fijo (de
/// 9 a 10 km/h la ficha no baila), la unidad en pequeño y un rótulo. Sin
/// animación ni colores por rango: la cifra cambia con cada posición y
/// tiene que leerse, no llamar la atención.
///
/// `kmh` es `null` cuando no hay nada fiable que enseñar —el bus no está en
/// línea, o el dato no es una velocidad posible— y entonces va una raya.
class VelocidadBus extends StatelessWidget {
  const VelocidadBus({super.key, required this.kmh});

  final double? kmh;

  @override
  Widget build(BuildContext context) {
    final valor = kmh;
    final cifra = valor != null && valor.isFinite && valor >= 0
        ? '${valor.round()}'
        : null;
    // Cambia con cada posición: pinta en su propia capa.
    return RepaintBoundary(
      child: Semantics(
        label: cifra == null
            ? 'Velocidad: sin dato'
            : 'Velocidad: $cifra km/h',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // El mismo rótulo en versalitas espaciadas que usa el panel.
            Text(
              'VELOCIDAD',
              style: AppType.mono(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // 30 pt frente a los 15,5 de la placa: es la cifra de la
                // ficha. `height: 1` quita el aire de la fuente para que el
                // bloque no crezca más que el número.
                Text(
                  cifra ?? '—',
                  style: AppType.mono(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1,
                    color: cifra == null
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
                if (cifra != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    'km/h',
                    style: AppType.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
