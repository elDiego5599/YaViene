import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../splash/presentation/widgets/escena_arranque.dart';
import '../../splash/presentation/widgets/fondo_matizado.dart';

/// Una ilustración del fondo de Info, en fracciones de la pantalla: [x] y
/// [ancho] del ancho, [y] del alto. [asset] nulo es la Ventana al Mundo del
/// arranque, que se pinta y no es foto.
typedef PiezaIlustrada = ({
  String? asset,
  double proporcion,
  double x,
  double y,
  double ancho,
  double giro,
});

extension RectDePieza on PiezaIlustrada {
  /// Donde cae sin girar, en una pantalla de [pantalla].
  Rect rectEn(Size pantalla) {
    final w = ancho * pantalla.width;
    return Rect.fromLTWH(
        x * pantalla.width, y * pantalla.height, w, w * proporcion);
  }
}

/// El fondo de Info (dueño, 2026-10-18: «mejor con las fotos animadas, que
/// se ven bien detalladas y bonitas, le darán un look más elegante y
/// sofisticado»): en vez del mosaico, pocas ilustraciones grandes de
/// Barranquilla sueltas en las orillas —arriba la cayena y el sol, abajo la
/// Ventana al Mundo del arranque, la palmera, la marimonda y dos buses—
/// sobre el mismo matizado del arranque. Cada una con una sombra suave,
/// como recortada y puesta encima. Quieto; las tarjetas blancas van por
/// encima.
class FondoIlustrado extends StatelessWidget {
  const FondoIlustrado({super.key, required this.child});

  final Widget child;

  /// Las proporciones son las de cada archivo (`fondo_ilustrado_test`).
  static const List<PiezaIlustrada> piezas = [
    // Arriba, asomados por las esquinas a los lados de la marca.
    (
      asset: 'assets/images/info_flor.webp',
      proporcion: 445 / 450,
      x: -0.10,
      y: -0.015,
      ancho: 0.40,
      giro: -14,
    ),
    (
      asset: 'assets/images/info_sol.webp',
      proporcion: 447 / 450,
      x: 0.76,
      y: -0.025,
      ancho: 0.32,
      giro: 8,
    ),
    // Abajo, la ciudad: la torre del arranque, entera (dueño, 2026-10-18),
    // la palmera, la marimonda y los buses de las dos empresas al pie.
    (
      asset: null,
      proporcion: 1 / PintorVentana.aspecto,
      x: 0.03,
      y: 0.585,
      ancho: 0.25,
      giro: -4,
    ),
    (
      asset: 'assets/images/info_palmera.webp',
      proporcion: 592 / 420,
      x: 0.30,
      y: 0.585,
      ancho: 0.32,
      giro: 0,
    ),
    (
      asset: 'assets/images/info_marimonda.webp',
      proporcion: 418 / 450,
      x: 0.64,
      y: 0.615,
      ancho: 0.40,
      giro: 10,
    ),
    (
      asset: 'assets/images/info_sobusa.webp',
      proporcion: 245 / 223,
      x: 0.30,
      y: 0.805,
      ancho: 0.20,
      giro: -3,
    ),
    (
      asset: 'assets/images/info_coolitoral.webp',
      proporcion: 248 / 270,
      x: 0.56,
      y: 0.805,
      ancho: 0.22,
      giro: 3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Aparte: el fondo se pinta una vez y no al desplazar la lista.
        RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, caja) => Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: PintorMatizado()),
                ),
                for (final p in piezas) _pieza(p, caja.biggest),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _pieza(PiezaIlustrada p, Size pantalla) {
    Widget dibujo() => p.asset == null
        ? CustomPaint(painter: PintorVentana(1))
        : Image.asset(
            p.asset!,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            filterQuality: FilterQuality.medium,
          );
    final r = p.rectEn(pantalla);
    return Positioned.fromRect(
      rect: r,
      child: Transform.rotate(
        angle: p.giro * math.pi / 180,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // La sombra: la misma silueta en tinta, borrosa y corrida hacia
            // abajo, como papel recortado sobre el matizado.
            Transform.translate(
              offset: Offset(0, r.width * 0.03),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                    sigmaX: r.width * 0.04, sigmaY: r.width * 0.04),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                      AppColors.ink.withValues(alpha: 0.22), BlendMode.srcIn),
                  child: dibujo(),
                ),
              ),
            ),
            dibujo(),
          ],
        ),
      ),
    );
  }
}
