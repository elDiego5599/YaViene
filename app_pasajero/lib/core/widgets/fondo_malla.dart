import 'package:flutter/material.dart';

/// El fondo del arranque y de la pestaña de Info (dueño, 2026-10-16): una
/// malla de color difuminada con los colores de la marca, del verde arriba
/// al azul y la tinta abajo, en vez de la tinta plana con su red de rutas.
///
/// Quieta a propósito: un fondo que se mueve en toda la pantalla marea, y
/// con movimiento reducido no habría nada que apagar. Cada color está
/// medido (`test/fondo_malla_test.dart`): el blanco chico se lee en la
/// franja de la bajada y abajo, el grande arriba, y el disco verde del
/// logo no se pierde en el verde de alrededor.
class FondoMalla extends StatelessWidget {
  const FondoMalla({super.key, required this.child});

  final Widget child;

  /// El blanco de la letra chica sobre la malla: la bajada del arranque y
  /// los créditos de Info. Al 75 % la bajada medía 4,02:1 en su franja; al
  /// 90 % pasa AA (`test/fondo_malla_test.dart`).
  static const double alfaLetraChica = 0.9;

  /// El pintor solo, para medir sus píxeles.
  static CustomPainter pintor() => const _PintorMalla();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _PintorMalla(),
      child: SizedBox.expand(child: child),
    );
  }
}

class _PintorMalla extends CustomPainter {
  const _PintorMalla();

  /// La base, de arriba abajo: el verde de la marca se hunde en un verde
  /// azulado detrás del logo y termina en la tinta del panel.
  static const _base = [
    Color(0xFF00A859),
    Color(0xFF008A5C),
    Color(0xFF0A6E66),
    Color(0xFF145487),
    Color(0xFF17325F),
  ];
  static const _paradas = [0.0, 0.24, 0.46, 0.72, 1.0];

  /// Las manchas que la vuelven malla: (color, centro en fracción de la
  /// pantalla, radio en fracción del ancho).
  static const _manchas = [
    (Color(0xFF00A859), Offset(0.0, 0.0), 0.95),
    (Color(0xE61E56A8), Offset(1.1, 0.16), 0.75),
    (Color(0xFF1E56A8), Offset(1.05, 0.66), 1.0),
    (Color(0xFF17325F), Offset(0.85, 1.08), 0.8),
    // El verde vuelve abajo a la izquierda (dueño, 2026-10-16: «que abajo
    // también haya verde»), hondo para que el blanco chico se siga leyendo,
    // y más vivo solo en la esquina, donde va la barra y no hay letra.
    (Color(0xF2047857), Offset(-0.1, 0.62), 0.8),
    (Color(0xFF047857), Offset(0.0, 0.92), 0.85),
    (Color(0xCC00A859), Offset(-0.05, 1.04), 0.5),
    // Cruzadas, para que no quede partida en dos: un verde hondo se mete
    // por la derecha a media altura y un azul por la izquierda más abajo.
    (Color(0xD9047857), Offset(0.95, 0.4), 0.5),
    (Color(0xB31E56A8), Offset(0.3, 0.8), 0.36),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final todo = Offset.zero & size;
    canvas.drawRect(
      todo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _base,
          stops: _paradas,
        ).createShader(todo),
    );
    for (final (color, centro, radio) in _manchas) {
      final c = Offset(centro.dx * size.width, centro.dy * size.height);
      final r = radio * size.width;
      canvas.drawRect(
        todo,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorMalla oldDelegate) => false;
}
