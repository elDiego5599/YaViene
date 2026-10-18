import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// El fondo de la bienvenida y de la pestaña de Info (dueño,
/// 2026-10-16): una malla de color difuminada con los colores de la marca,
/// del verde arriba al azul y la tinta abajo, en vez de la tinta plana con
/// su red de rutas.
///
/// Respira (dueño, 2026-10-16: «que no fuera un fondo estático, que parezca
/// moverse y respirar»): cada mancha da una vuelta chica alrededor de su
/// sitio y crece y mengua un poco, en un ciclo de [vuelta]. Lento a
/// propósito —lejos del ciclo de cinco segundos que marea— y empieza
/// siempre en la misma foto. Con «Reducir movimiento» se queda quieta en
/// esa foto. Cada color
/// está medido en todo el ciclo (`test/fondo_malla_test.dart`).
class FondoMalla extends StatefulWidget {
  const FondoMalla({
    super.key,
    required this.child,
    this.suave = false,
    this.subida = 0,
  });

  final Widget child;

  /// Cuánto sube la malla, en fracción del alto. La bienvenida pone la
  /// marca más arriba del centro, porque abajo va su hoja: subiendo la
  /// malla con ella, la bajada cae en el mismo tono hondo donde se lee y no
  /// en el verde vivo de arriba (`test/onboarding_hoja_test.dart`). Lo que
  /// queda abajo sin malla sigue en la tinta del final.
  final double subida;

  /// Bajo un velo blanco: la de Info, que con la malla entera «se ve muy
  /// fuerte, muy brillante» (dueño, 2026-10-16). Lleva letra de tinta.
  final bool suave;

  /// El blanco de la letra chica sobre la malla: la bajada de la marca.
  /// Al 75 % la bajada medía 4,02:1 en su franja; al 90 % pasa AA
  /// (`test/fondo_malla_test.dart`).
  static const double alfaLetraChica = 0.9;

  /// Lo que tapa el velo de Info: deja la marca en un tinte pastel y la
  /// letra de encima por sobre 4,5:1 en todo el ciclo: al 88 % los créditos
  /// grises daban 4,37:1 abajo, en el verde.
  static const double alfaVelo = 0.9;

  /// Un ciclo entero de la respiración.
  static const Duration vuelta = Duration(seconds: 24);

  /// El pintor solo, en un momento del ciclo, para medir sus píxeles.
  static CustomPainter pintor(
          {double fase = 0, bool suave = false, double subida = 0}) =>
      PintorMalla(AlwaysStoppedAnimation(fase), suave: suave, subida: subida);

  @override
  State<FondoMalla> createState() => _FondoMallaState();
}

class _FondoMallaState extends State<FondoMalla>
    with SingleTickerProviderStateMixin {
  AnimationController? _ciclo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La preferencia puede cambiar con la app abierta: se para donde va (un
    // salto a la foto inicial sería justo el movimiento que se pidió
    // quitar) y vuelve a andar si se apaga.
    if (AppMotion.reducido(context)) {
      _ciclo?.stop();
      return;
    }
    final ciclo = _ciclo ??=
        AnimationController(vsync: this, duration: FondoMalla.vuelta);
    if (!ciclo.isAnimating) ciclo.repeat();
  }

  @override
  void dispose() {
    _ciclo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Aparte, para que cada cuadro de la malla no vuelva a pintar lo
        // que lleva encima.
        RepaintBoundary(
          child: CustomPaint(
            painter: PintorMalla(
              _ciclo ?? const AlwaysStoppedAnimation(0),
              suave: widget.suave,
              subida: widget.subida,
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// La malla en un momento de su ciclo ([fase], de 0 a 1).
class PintorMalla extends CustomPainter {
  PintorMalla(this._ciclo, {this.suave = false, this.subida = 0})
      : super(repaint: _ciclo);

  final Animation<double> _ciclo;
  final bool suave;
  final double subida;

  double get fase => _ciclo.value;

  /// Cuánto se aleja cada mancha de su sitio, en fracción de la pantalla,
  /// y cuánto crece o mengua su radio: lo bastante para que se note vivo,
  /// poco para que nada medido deje de pasar.
  static const _paseo = 0.05;
  static const _aliento = 0.08;

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
        ).createShader(todo.shift(Offset(0, -subida * size.height))),
    );
    final giro = 2 * math.pi * fase;
    for (final (i, (color, centro, radio)) in _manchas.indexed) {
      // Una vuelta chica alrededor del sitio, unas a un lado y otras al
      // otro, cada una desde su punto del círculo. Restar el arranque deja
      // la fase 0 donde siempre estuvo: la foto quieta. Vueltas enteras,
      // para que el final del ciclo empalme con el principio.
      final sentido = i.isEven ? 1 : -1;
      final desde = i * 0.7;
      final paseo = Offset(
        math.sin(sentido * giro + desde) - math.sin(desde),
        math.cos(sentido * giro + desde) - math.cos(desde),
      );
      final c = Offset(
        (centro.dx + _paseo * paseo.dx) * size.width,
        (centro.dy - subida + _paseo * paseo.dy) * size.height,
      );
      final r =
          radio * size.width * (1 + _aliento * math.sin((i % 2 + 1) * giro));
      canvas.drawRect(
        todo,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    if (suave) {
      canvas.drawRect(
        todo,
        Paint()..color = Colors.white.withValues(alpha: FondoMalla.alfaVelo),
      );
    }
  }

  @override
  bool shouldRepaint(PintorMalla antes) =>
      antes._ciclo != _ciclo || antes.suave != suave || antes.subida != subida;
}
