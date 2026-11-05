import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/utils/color_empresa.dart';
import '../../../../core/widgets/latido.dart';
import 'sena_tomar_ruta.dart';

/// El dibujo de «Escoge empresa y ruta»: tres insignias de ruta en abanico,
/// cada una en el color de su empresa y con su código en blanco, como en
/// «Elige ruta». La del frente se alza, las de atrás se abren un poco para
/// dejarla salir, y cae con el resorte de lo que se acaba de marcar
/// (`AppMotion.curvaRebote`) con un chulito verde de escogida. Luego descansa y
/// vuelve a escoger.
///
/// Reemplaza el `Icons.route_outlined` gris (dueño, 2026-11-05: junto al pin
/// de «Toca el mapa donde tomas tu bus» «se ve horrible»). Una miniatura del
/// selector con sus filas se leía como «una lista cualquiera», y un bus y
/// una ruta dibujados a 14 px se veían mal; la insignia es lo que el
/// pasajero ya conoce del selector y de la ficha del aviso: colores
/// distintos son empresas distintas, y la que sube es la que escoge.
class SenaElegirRuta extends StatelessWidget {
  const SenaElegirRuta({super.key, this.lado = 56});

  /// El lado del medallón en que se dibuja.
  final double lado;

  /// Lo que dura escoger. El mismo de `SenaTocarBus` y `SenaTomarRuta`:
  /// las señas de la hoja laten parejo.
  static const toque = Duration(milliseconds: 1400);

  /// El descanso entre una y otra, el de las otras dos señas.
  static const pausa = Duration(milliseconds: 2400);

  /// Cuánto está alzada la insignia del frente en el punto `t` (0 → 1):
  /// 0 en su sitio, 1 arriba del todo. Es la curva del pin de
  /// `SenaTomarRuta` (sube suave hasta el 22 %, cae con el resorte hasta
  /// el 62 %): las dos señas vecinas saltan igual. Lo que se pasa bajo
  /// cero es la insignia que se asienta.
  static double alzada(double t) => SenaTomarRuta.alzada(t);

  /// Cuánto se abren las insignias de atrás (0 → 1): siguen a la del
  /// frente un poco después y vuelven amortiguadas, sin pasarse, para que
  /// el abanico no tiemble.
  static double apertura(double t) {
    if (t <= 0.04) return 0;
    if (t < 0.26) return Curves.easeOutCubic.transform((t - 0.04) / 0.22);
    if (t < 0.70) {
      return 1 - AppMotion.curvaEntrada.transform((t - 0.26) / 0.44);
    }
    return 0;
  }

  /// El chulito de «escogida» en el punto `t`: nada mientras la insignia
  /// sube, brota con el resorte de lo que se acaba de marcar cuando vuelve
  /// a su sitio (t = 0,40), se queda y se apaga al final, para que la
  /// pose del descanso sea la del arranque. `escala` es su tamaño (se pasa
  /// un 4,6 % al brotar) y `opacidad` lo que se ve.
  static ({double escala, double opacidad}) marca(double t) {
    if (t <= 0.40 || t >= 1) return (escala: 0, opacidad: 0);
    if (t < 0.70) {
      final brota = AppMotion.curvaRebote.transform((t - 0.40) / 0.30);
      return (escala: brota, opacidad: (brota * 2).clamp(0.0, 1.0));
    }
    if (t < 0.86) return (escala: 1, opacidad: 1);
    final se = Curves.easeInCubic.transform((t - 0.86) / 0.14);
    return (escala: 1 - 0.4 * se, opacidad: 1 - se);
  }

  @override
  Widget build(BuildContext context) {
    return Latido(
      dura: toque,
      pausa: pausa,
      builder: (context, t, quieto, _) => CustomPaint(
        size: Size.square(lado),
        painter: _PintorAbanico(t: t, quieto: quieto),
      ),
    );
  }
}

class _PintorAbanico extends CustomPainter {
  const _PintorAbanico({required this.t, required this.quieto});

  final double t;
  final bool quieto;

  /// El lado de la insignia del frente en fracción del medallón: 23,5 px
  /// en 56. La de «Elige ruta» mide 44 con radio 12 y su código en 13 pt;
  /// aquí radio y letra van a esa misma escala.
  static const _lado = 0.42;
  static const _radio = 12 / 44;
  static const _letra = 13 / 44;

  /// Las de atrás van al 92 % y sin código: solo asoman sus esquinas,
  /// y un código a medias detrás del frente se leía como un borrón.
  static const _atras = 0.92;

  /// Las de atrás giran desde un punto bajo la del frente, como cartas
  /// en la mano: 11° en reposo, 17° abiertas. El eje queda 0,50 del lado
  /// bajo el centro y las cartas suben 0,07 sobre la del frente, así
  /// asoman por arriba y a los lados, y por abajo quedan tapadas.
  static const _giro = 11 * math.pi / 180;
  static const _giroAbierto = 17 * math.pi / 180;
  static const _eje = 0.50;
  static const _asoma = 0.07;

  /// Lo que sube la del frente, en fracción del lado: 6 px en 56, como el
  /// pin de `SenaTomarRuta`.
  static const _subida = 0.11;

  /// La del frente baja 0,05 del centro para que el abanico, que sube por
  /// detrás, quede centrado en el medallón.
  static const _abajo = 0.05;

  /// Tres empresas, tres colores: atrás el petróleo y el bosque del
  /// escalón de `coloresEmpresa`, y al frente el rojo de Coochofal, que es
  /// el que más se despega de los otros dos. En vez de un código, la
  /// palabra «Ruta» (dueño, 2026-11-05): un código suelto como «R-111» no
  /// le decía nada a quien aún no ha escogido.
  static final _colorIzquierda = coloresEmpresa[2];
  static final _colorDerecha = coloresEmpresa[4];
  static const _codigo = 'Ruta';

  /// El chulito va en el verde de la marca con filo blanco, en la esquina
  /// de arriba a la derecha: 9 px de ancho en 56.
  static const _radioMarca = 0.085;

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    final posada = size.center(Offset.zero) + Offset(0, _abajo * lado);
    final abre = quieto ? 0.0 : SenaElegirRuta.apertura(t);
    final alza = quieto ? 0.0 : SenaElegirRuta.alzada(t);
    final eje = posada + Offset(0, _eje * lado);
    final giro = _giro + (_giroAbierto - _giro) * abre;

    for (final (lado: signo, color: color) in [
      (lado: -1.0, color: _colorIzquierda),
      (lado: 1.0, color: _colorDerecha),
    ]) {
      canvas
        ..save()
        ..translate(eje.dx, eje.dy)
        ..rotate(signo * giro)
        ..translate(0, -(_eje + _asoma) * lado);
      _caja(canvas, _lado * _atras * lado, color, sombra: 0.10);
      canvas.restore();
    }

    final arriba = posada - Offset(0, alza * _subida * lado);
    final s = _lado * lado;
    canvas
      ..save()
      ..translate(arriba.dx, arriba.dy);
    // Arriba proyecta más sombra: se lee que se despegó.
    _caja(canvas, s, rojoCoochofal, sombra: 0.18 + 0.10 * alza.clamp(0, 1));
    _codigoEn(canvas, s);

    // Sin movimiento queda el chulito fijo: sin el salto, es lo que dice
    // «escoge».
    final m = quieto ? (escala: 1.0, opacidad: 1.0) : SenaElegirRuta.marca(t);
    if (m.opacidad > 0) {
      final r = _radioMarca * lado * m.escala;
      final c = Offset(s / 2 - 0.02 * lado, -s / 2 + 0.02 * lado);
      final tinta = Paint()..color = Colors.white.withValues(alpha: m.opacidad);
      canvas
        ..drawCircle(c, r + 1.2, tinta)
        ..drawCircle(
          c,
          r,
          Paint()..color = AppColors.primary.withValues(alpha: m.opacidad),
        )
        ..drawPath(
          Path()
            ..moveTo(c.dx - r * 0.45, c.dy + r * 0.02)
            ..lineTo(c.dx - r * 0.10, c.dy + r * 0.38)
            ..lineTo(c.dx + r * 0.50, c.dy - r * 0.34),
          tinta
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.30
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
    }
    canvas.restore();
  }

  /// Una insignia centrada en el origen: su color, su sombra y un filo
  /// blanco que la separa de la que tiene detrás (sin él, dos colores
  /// oscuros se funden en el cruce).
  void _caja(Canvas canvas, double s, Color color, {required double sombra}) {
    final caja = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s, height: s),
      Radius.circular(s * _radio),
    );
    canvas
      ..drawShadow(
        Path()..addRRect(caja),
        Colors.black.withValues(alpha: sombra),
        2.5,
        false,
      )
      ..drawRRect(caja, Paint()..color = color)
      ..drawRRect(
        caja,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white,
      );
  }

  /// El código en blanco, centrado en el origen. Como el FittedBox de la
  /// insignia real: un código largo se encoge para caber en la caja menos
  /// 4 de margen por lado (a escala).
  void _codigoEn(Canvas canvas, double s) {
    final texto = TextPainter(
      text: TextSpan(
        text: _codigo,
        style: AppTextStyles.etiqueta.copyWith(
          color: Colors.white,
          fontSize: _letra * s,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final escala = math.min(1.0, s * (1 - 8 / 44) / texto.width);
    canvas
      ..save()
      ..scale(escala)
      ..translate(-texto.width / 2, -texto.height / 2);
    texto.paint(canvas, Offset.zero);
    texto.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorAbanico viejo) =>
      viejo.t != t || viejo.quieto != quieto;
}
