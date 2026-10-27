import 'package:flutter/material.dart';

/// La cabecera de Avisos y Buzón, bajo la barra (dueño, 2026-10-26: «en
/// vez de gris usemos un degradadito fino entre azul y verde, algo bien
/// lindo como la foto»). Los tonos del matizado de la bienvenida
/// (`PintorMatizado`), de izquierda a derecha, con un brillo blanco difuso
/// arriba a la izquierda para que se vea luz y no una franja plana. El
/// título va en tinta: sobre el tono más oscuro (el azul) da 14,0:1
/// (`test/cabecera_degradada_test.dart`).
class CabeceraDegradada extends StatelessWidget {
  const CabeceraDegradada({super.key});

  /// Azul, el claro del medio y verde: los extremos son las manchas de la
  /// bienvenida, un punto más vivas para que se lean en una franja corta.
  static const azul = Color(0xFFD7E5F8);
  static const verde = Color(0xFFD3F0E0);
  static const _medio = Color(0xFFE6F1F5);

  /// Media línea de tinta al 8 %: la raya de siempre (dueño, 2026-10-19:
  /// «que no se note mucho, algo sutil»).
  static const raya = BorderSide(color: Color(0x140B1628), width: 0.5);

  static const decoracion = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [azul, _medio, verde],
    ),
    border: Border(bottom: raya),
  );

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: decoracion,
      // El brillo: blanco al 70 % que se apaga antes de la mitad.
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.55, -1.2),
            radius: 1.6,
            colors: [Color(0xB3FFFFFF), Color(0x00FFFFFF)],
          ),
        ),
      ),
    );
  }
}
