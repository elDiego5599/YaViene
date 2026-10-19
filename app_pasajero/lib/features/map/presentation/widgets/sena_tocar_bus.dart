import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/widgets/latido.dart';

/// El dibujo de «Toca un bus en el mapa»: el mismo bus del mapa en
/// miniatura, y un toque que lo marca. El bus se hunde un poco, como bajo
/// un dedo, y de él salen dos anillos que se apagan —el toque y su eco—.
/// Luego descansa y vuelve a tocar.
///
/// Reemplaza la mano de Material (dueño, 2026-09-27: «no me gusta nada»).
/// La mano decía «toca» en general; el bus dice qué tocar, y es idéntico al
/// que el pasajero ve en el mapa: la cápsula de `createFlatTransitMarker`
/// (map_markers.dart), con sus mismas proporciones, color, anillo blanco y
/// parabrisas. Los anillos van en el color del bus porque salen de él.
class SenaTocarBus extends StatelessWidget {
  const SenaTocarBus({super.key, this.lado = 56});

  /// El lado del medallón en que se dibuja: los anillos llegan hasta su
  /// borde y no se salen.
  final double lado;

  /// Lo que dura un toque, del hundido a que se apaga el eco.
  static const toque = Duration(milliseconds: 1400);

  /// El descanso entre toques. Más largo que el destello de «Ruta activa»
  /// (1,4 s): esto es una sugerencia, no un estado vivo, y no debe competir
  /// con el mapa por la mirada.
  static const pausa = Duration(milliseconds: 2400);

  /// El alto del bus respecto del medallón. En el mapa la cápsula es de
  /// 60 × 32 en un lienzo de 96; aquí mide 0,42 del lado —23,5 px en el
  /// medallón de 56— para que a los anillos les quede aire alrededor.
  static const _altoBus = 0.42;

  /// Cuánto se hunde el bus bajo el dedo: al 92 %. Menos no se ve; más ya
  /// parece que se encoge.
  static const _hundido = 0.92;

  /// El tamaño del bus en el punto `t` (0 → 1) del toque: baja en el
  /// primer 10 % y vuelve con un leve rebote hasta el 38 %.
  static double escalaBus(double t) {
    if (t <= 0.1) {
      return 1 - (1 - _hundido) * Curves.easeOut.transform(t / 0.1);
    }
    if (t >= 0.38) return 1;
    final vuelta = Curves.easeOutBack.transform((t - 0.1) / 0.28);
    return _hundido + (1 - _hundido) * vuelta;
  }

  /// El anillo `n` (1 = el toque, 2 = el eco) en el punto `t` del toque.
  /// `radio` es fracción del lado: sale junto al bus (0,24) y llega al
  /// borde del medallón (0,47). La opacidad entra en un décimo de su vida
  /// y se apaga mientras crece: al empezar y al terminar vale 0.
  static ({double radio, double opacidad}) anillo(int n, double t) {
    final (desde, hasta, pico) =
        n == 1 ? (0.06, 0.70, 0.55) : (0.20, 0.84, 0.32);
    final local = ((t - desde) / (hasta - desde)).clamp(0.0, 1.0);
    final crece = Curves.easeOutCubic.transform(local);
    final entra = (local / 0.1).clamp(0.0, 1.0);
    return (
      radio: 0.24 + (0.47 - 0.24) * crece,
      opacidad: local == 0 ? 0.0 : pico * entra * (1 - crece),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Latido(
      dura: toque,
      pausa: pausa,
      builder: (context, t, quieto, _) => CustomPaint(
        size: Size.square(lado),
        painter: _PintorToque(t: t, quieto: quieto),
      ),
    );
  }
}

class _PintorToque extends CustomPainter {
  const _PintorToque({required this.t, required this.quieto});

  final double t;
  final bool quieto;

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    final centro = size.center(Offset.zero);

    if (quieto) {
      // Sin movimiento, un solo anillo tenue a medio camino: el toque
      // congelado, para que el dibujo siga diciendo «toca».
      _anillo(canvas, centro, 0.36 * lado, 0.22);
    } else {
      for (final n in const [1, 2]) {
        final a = SenaTocarBus.anillo(n, t);
        if (a.opacidad > 0) _anillo(canvas, centro, a.radio * lado, a.opacidad);
      }
    }

    final escala = quieto ? 1.0 : SenaTocarBus.escalaBus(t);
    final alto = SenaTocarBus._altoBus * lado;
    // Las mismas proporciones de la cápsula del mapa: 60 de alto, 32 de ancho.
    final ancho = alto * 32 / 60;
    final capsula = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: ancho, height: alto),
      Radius.circular(ancho / 2),
    );

    canvas
      ..save()
      ..translate(centro.dx, centro.dy)
      ..scale(escala);

    // La sombra de contacto del mapa (`map_markers.dart`): gris, centrada
    // y en la misma proporción, 2,4 sobre 60 de alto. Antes era del color
    // del bus, y en el mapa esa sombra se leía como una estela (dueño,
    // 2026-09-30): la seña enseña el bus tal como se ve allá.
    canvas.drawRRect(
      capsula,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, alto * 0.04),
    );
    canvas.drawRRect(
      capsula,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(AppColors.busActive, Colors.white, 0.3)!,
            AppColors.busActive,
          ],
        ).createShader(capsula.outerRect),
    );
    // Anillo blanco y parabrisas, a la escala del mapa (2,6 de 60).
    canvas.drawRRect(
      capsula,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = alto * 2.6 / 60
        ..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas
      ..save()
      ..clipRRect(capsula)
      ..drawOval(
        Rect.fromCenter(
          center: Offset(0, -alto * 0.26),
          width: ancho * 0.72,
          height: alto * 0.26,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.3),
      )
      ..restore()
      ..restore();
  }

  void _anillo(Canvas canvas, Offset centro, double radio, double opacidad) {
    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.busActive.withValues(alpha: opacidad),
    );
  }

  @override
  bool shouldRepaint(_PintorToque viejo) =>
      viejo.t != t || viejo.quieto != quieto;
}
