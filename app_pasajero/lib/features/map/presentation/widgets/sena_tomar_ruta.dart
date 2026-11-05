import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/widgets/latido.dart';

/// El dibujo de «Toca el mapa donde tomas tu bus»: un trozo de calle con la
/// ruta encima y el pin del mapa posado en ella. El pin da un saltito, cae
/// con el mismo resorte con que salta a la ruta en el mapa
/// (`AppMotion.curvaRebote`) y deja un anillo verde donde se posa. Luego
/// descansa y vuelve a saltar.
///
/// Reemplaza la mano de Material (dueño, 2026-11-05, «ponle un icono más
/// bonito»): la mano decía «toca»; esto dice qué pasa al tocar, que el
/// punto se pega a la ruta. Calle, orla y línea son las del mapa
/// (`EstiloRuta`: verde de 4 sobre orla blanca de 8, aquí a 0,8) y el pin
/// es el de `createPinMarker` (map_markers.dart), con su gota, su
/// degradado y su ojo blanco.
class SenaTomarRuta extends StatelessWidget {
  const SenaTomarRuta({super.key, this.lado = 56});

  /// El lado del medallón en que se dibuja.
  final double lado;

  /// Lo que dura un salto, de que despega a que se apaga el anillo. Igual
  /// que el toque de `SenaTocarBus`: las dos señas de la hoja laten parejo.
  static const salto = Duration(milliseconds: 1400);

  /// El descanso entre saltos, el mismo de `SenaTocarBus`: es una
  /// sugerencia y no compite con el mapa por la mirada.
  static const pausa = Duration(milliseconds: 2400);

  /// Lo que sube el pin, en fracción del lado: 6,2 px en el medallón de
  /// 56. Menos no se lee como salto; con 0,14 se despegaba tanto de la
  /// calle que dejaba de leerse como «se pega a la ruta».
  static const _subida = 0.11;

  /// El alto del pin (de la cabeza a la punta) en fracción del lado: 26 px
  /// en 56, la mitad del medallón, para que la calle se vea entera.
  static const _altoPin = 0.46;

  /// Cuánto está alzado el pin en el punto `t` (0 → 1) del salto: 0 posado,
  /// 1 arriba del todo. Sube suave hasta el 22 % y cae con el resorte del
  /// mapa hasta el 62 %; el resorte se pasa un 4,6 %, y ese poquito bajo
  /// cero es el pin que se hunde al posarse.
  static double alzada(double t) {
    if (t <= 0) return 0;
    if (t < 0.22) return Curves.easeOutCubic.transform(t / 0.22);
    if (t < 0.62) {
      return 1 - AppMotion.curvaRebote.transform((t - 0.22) / 0.40);
    }
    return 0;
  }

  /// El anillo que deja el pin al posarse, en el punto `t` del salto.
  /// `radio` es fracción del lado: sale de la punta (0,05) y se abre hasta
  /// 0,26, sin tocar el borde. Nace cuando el resorte llega a la calle
  /// (t = 0,36) y se apaga mientras crece: al empezar y al terminar vale 0.
  static ({double radio, double opacidad}) anillo(double t) {
    const desde = 0.36, hasta = 1.0, pico = 0.5;
    final local = ((t - desde) / (hasta - desde)).clamp(0.0, 1.0);
    final crece = Curves.easeOutCubic.transform(local);
    final entra = (local / 0.1).clamp(0.0, 1.0);
    return (
      radio: 0.05 + (0.26 - 0.05) * crece,
      opacidad: local == 0 || local == 1 ? 0.0 : pico * entra * (1 - crece),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Latido(
      dura: salto,
      pausa: pausa,
      builder: (context, t, quieto, _) => CustomPaint(
        size: Size.square(lado),
        painter: _PintorSalto(t: t, quieto: quieto),
      ),
    );
  }
}

class _PintorSalto extends CustomPainter {
  const _PintorSalto({required this.t, required this.quieto});

  final double t;
  final bool quieto;

  /// La calle del mapa retocado (`estilo_retocado.dart`) es gris azulado
  /// sobre papel; aquí, sobre el blanco del medallón, un gris claro de esa
  /// familia para que la orla blanca de la ruta se vea.
  static const _calle = Color(0xFFE4E8EF);

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    Offset p(double x, double y) => Offset(x * lado, y * lado);

    // Una curva suave de abajo a la izquierda a arriba a la derecha: una
    // calle que dobla, no una raya. Simétrica alrededor del centro: el pin
    // se posa en su mitad, en x = 0,5, y el conjunto queda centrado.
    final ruta = Path()
      ..moveTo(p(0.12, 0.77).dx, p(0.12, 0.77).dy)
      ..cubicTo(
        p(0.40, 0.77).dx,
        p(0.40, 0.77).dy,
        p(0.60, 0.57).dx,
        p(0.60, 0.57).dy,
        p(0.88, 0.57).dx,
        p(0.88, 0.57).dy,
      );
    final metrica = ruta.computeMetrics().first;
    final posada = metrica.getTangentForOffset(metrica.length / 2)!.position;

    Paint trazo(Color color, double ancho) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = ancho
      ..color = color;
    canvas
      ..drawPath(ruta, trazo(_calle, lado * 0.17))
      ..drawPath(ruta, trazo(Colors.white, 6.4))
      ..drawPath(ruta, trazo(AppColors.primary, 3.2));

    final a = quieto ? (radio: 0.18, opacidad: 0.18) : SenaTomarRuta.anillo(t);
    if (a.opacidad > 0) {
      canvas.drawCircle(
        posada,
        a.radio * lado,
        trazo(AppColors.primary.withValues(alpha: a.opacidad), 1.4),
      );
    }

    final alzada = quieto ? 0.0 : SenaTomarRuta.alzada(t);
    // La sombra de contacto se encoge y aclara mientras el pin está arriba.
    final lejos = alzada.clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: posada,
        width: lado * 0.20 * (1 - 0.35 * lejos),
        height: lado * 0.06 * (1 - 0.35 * lejos),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22 * (1 - 0.5 * lejos))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

    canvas
      ..save()
      ..translate(posada.dx, posada.dy - alzada * SenaTomarRuta._subida * lado)
      // El pin del mapa mide 72 de la cabeza a la punta en su lienzo de 80.
      ..scale(SenaTomarRuta._altoPin * lado / 72);
    _pin(canvas);
    canvas.restore();
  }

  /// La gota de `createPinMarker` con la punta en el origen: las mismas
  /// curvas, el mismo degradado, el brillo y el ojo blanco con su centro.
  void _pin(Canvas canvas) {
    const cabezaY = -46.0, radio = 26.0;
    final gota = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-30, -28, -radio, cabezaY)
      ..arcTo(
        Rect.fromCircle(center: const Offset(0, cabezaY), radius: radio),
        math.pi,
        math.pi,
        false,
      )
      ..quadraticBezierTo(30, -28, 0, 0);
    canvas
      ..drawShadow(gota, Colors.black.withValues(alpha: 0.25), 4, false)
      ..drawPath(
        gota,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, -72),
            Offset.zero,
            const [Color(0xFF4ADE80), Color(0xFF059669)],
          ),
      )
      ..drawOval(
        Rect.fromCenter(
            center: const Offset(0, cabezaY - 16), width: 24, height: 9),
        Paint()..color = Colors.white.withValues(alpha: 0.20),
      )
      ..drawCircle(
          const Offset(0, cabezaY), 12.5, Paint()..color = Colors.white)
      ..drawCircle(
        const Offset(0, cabezaY),
        8.5,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(-9, cabezaY - 9),
            const Offset(9, cabezaY + 9),
            const [Color(0xFF065F46), AppColors.primary],
          ),
      )
      ..drawCircle(const Offset(-2.5, cabezaY - 3), 2.2,
          Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(_PintorSalto viejo) =>
      viejo.t != t || viejo.quieto != quieto;
}
