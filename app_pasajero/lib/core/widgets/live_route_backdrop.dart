import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// El fondo de las tres pantallas oscuras: arranque, entrada y bienvenida.
///
/// Antes era tinta plana con un puntillado al 6 % —que en un teléfono no
/// se ve— y el logo encima. Tres pantallas seguidas de nada, y una promesa
/// ("tu ciudad en tiempo real") escrita pero no mostrada. Ahora el fondo es
/// lo que la app hace: una red de rutas de noche, con paradas, y un bus
/// recorriendo una de ellas mientras el usuario escribe su correo.
///
/// Cuesta un controlador y un `CustomPaint` con dos curvas: no hay mapa ni
/// red viva en estas pantallas, así que no compite con el presupuesto de
/// 30 fps del mapa. Con movimiento reducido no se crea el controlador: el
/// bus se queda quieto en la ruta, que sigue contando lo mismo.
class LiveRouteBackdrop extends StatefulWidget {
  const LiveRouteBackdrop({
    super.key,
    required this.child,
    this.showUser = false,
    this.haloY = 0.30,
  });

  /// Dibuja el punto "aquí estás" sobre la ruta, con el bus acercándose.
  /// Lo usa la pantalla que pide el permiso de ubicación: enseña para qué
  /// sirve en vez de prometerlo.
  final bool showUser;

  /// Altura del halo verde, en fracción de la pantalla: donde vaya a caer
  /// la marca. El splash la centra; el login y la bienvenida la suben para
  /// dejarle sitio a la hoja.
  final double haloY;

  final Widget child;

  @override
  State<LiveRouteBackdrop> createState() => _LiveRouteBackdropState();
}

class _LiveRouteBackdropState extends State<LiveRouteBackdrop>
    with SingleTickerProviderStateMixin {
  /// Una vuelta completa del bus. Lenta a propósito: es ambiente, no un
  /// carrusel. A esta velocidad recorre media pantalla mientras alguien
  /// termina de escribir su correo.
  static const Duration _vuelta = Duration(seconds: 18);

  AnimationController? _controller;
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery no está disponible en initState, y la preferencia de
    // movimiento puede cambiar con la app abierta.
    final quieto = AppMotion.reducido(context);
    if (quieto) {
      _controller?.stop();
      return;
    }
    if (!_iniciado) {
      _iniciado = true;
      _controller = AnimationController(vsync: this, duration: _vuelta)
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> avance = _controller == null
        // Detenido, el bus se planta a media ruta: se sigue leyendo que hay
        // un bus en una ruta, que es todo lo que el fondo tiene que decir.
        ? const AlwaysStoppedAnimation<double>(0.58)
        : _controller!;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _RedDeRutasPainter(
              avance: avance,
              showUser: widget.showUser,
              haloY: widget.haloY,
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _RedDeRutasPainter extends CustomPainter {
  _RedDeRutasPainter({
    required this.avance,
    required this.showUser,
    required this.haloY,
  }) : super(repaint: avance);

  final Animation<double> avance;
  final bool showUser;
  final double haloY;

  /// Dónde espera el usuario, en fracción de la ruta principal. Justo
  /// pasada la mitad: el bus entra por la izquierda y se le acerca.
  static const double _dondeEspera = 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    _pintarCielo(canvas, size);
    _pintarPuntos(canvas, size);

    final quietas = [_rutaB(size), _rutaC(size)];
    final trazoQuieto = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.07);
    for (final ruta in quietas) {
      canvas.drawPath(ruta, trazoQuieto);
    }

    final principal = _rutaA(size);
    canvas.drawPath(
      principal,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.13),
    );

    final medida = principal.computeMetrics().first;
    _pintarParadas(canvas, medida);
    if (showUser) _pintarUsuario(canvas, medida);
    _pintarBus(canvas, medida);
  }

  /// Noche sobre la ciudad: la tinta se aclara hacia arriba y se hunde
  /// hacia abajo, donde va a apoyarse la hoja. Un plano de color liso es
  /// lo que hacía que estas pantallas parecieran una plantilla.
  void _pintarCielo(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF17325F),
            Color(0xFF102141),
            AppColors.ink,
            Color(0xFF071019),
          ],
          stops: [0.0, 0.34, 0.62, 1.0],
        ).createShader(rect),
    );
    // Un halo detrás del logo, para que la marca se apoye en algo y no
    // flote sobre un plano muerto.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * haloY),
          size.width * 0.72,
          [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.primary.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  /// Retícula de puntos que se apaga hacia abajo: da textura arriba, donde
  /// hay sitio, y desaparece antes de llegar a la hoja.
  void _pintarPuntos(Canvas canvas, Size size) {
    final pincel = Paint()..style = PaintingStyle.fill;
    const paso = 34.0;
    for (double y = 28; y < size.height * 0.72; y += paso) {
      final desvanecido = (1 - (y / (size.height * 0.72))).clamp(0.0, 1.0);
      pincel.color = Colors.white.withValues(alpha: 0.02 + 0.055 * desvanecido);
      final corrimiento = ((y / paso).round().isEven) ? 0.0 : 12.0;
      for (double x = 18; x < size.width; x += paso) {
        canvas.drawCircle(Offset(x + corrimiento, y), 1.5, pincel);
      }
    }
  }

  void _pintarParadas(Canvas canvas, ui.PathMetric medida) {
    final anillo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.28);
    final centro = Paint()..color = AppColors.ink;
    for (final fraccion in const [0.16, 0.40, 0.84]) {
      final punto = medida.getTangentForOffset(medida.length * fraccion);
      if (punto == null) continue;
      canvas.drawCircle(punto.position, 3.6, centro);
      canvas.drawCircle(punto.position, 3.6, anillo);
    }
  }

  void _pintarUsuario(Canvas canvas, ui.PathMetric medida) {
    final punto = medida.getTangentForOffset(medida.length * _dondeEspera);
    if (punto == null) return;
    final p = punto.position;

    // El pulso late cuatro veces por vuelta del bus: se nota que está vivo
    // sin llamar la atención cada segundo.
    final fase = (avance.value * 4) % 1.0;
    final radio = 8 + 26 * Curves.easeOut.transform(fase);
    canvas.drawCircle(
      p,
      radio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.electricBlue.withValues(alpha: 0.45 * (1 - fase)),
    );

    canvas.drawCircle(
      p,
      16,
      Paint()
        ..color = AppColors.electricBlue.withValues(alpha: 0.30)
        ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(p, 7.5, Paint()..color = Colors.white);
    canvas.drawCircle(p, 5.5, Paint()..color = AppColors.electricBlue);
  }

  void _pintarBus(Canvas canvas, ui.PathMetric medida) {
    final t = avance.value;
    final recorrido = medida.length * t;
    final punto = medida.getTangentForOffset(recorrido);
    if (punto == null) return;

    // Entra y sale por los bordes de la pantalla: se atenúa en el primer y
    // el último tramo para que no aparezca ni se corte de golpe.
    final entrada = (t / 0.06).clamp(0.0, 1.0);
    final salida = ((1 - t) / 0.06).clamp(0.0, 1.0);
    final visible = math.min(entrada, salida);
    if (visible <= 0.01) return;

    // La estela: cuatro tramos que se van encendiendo hacia el bus. Es lo
    // que convierte un punto en algo que va llegando.
    const largoEstela = 0.13;
    const tramos = 4;
    for (var i = 0; i < tramos; i++) {
      final desde =
          recorrido - medida.length * largoEstela * (tramos - i) / tramos;
      final hasta =
          recorrido - medida.length * largoEstela * (tramos - i - 1) / tramos;
      if (hasta <= 0) continue;
      final trozo = medida.extractPath(math.max(0, desde), hasta);
      canvas.drawPath(
        trozo,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primary
              .withValues(alpha: 0.10 + 0.42 * (i / (tramos - 1)) * visible),
      );
    }

    final p = punto.position;
    canvas.drawCircle(
      p,
      18,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.45 * visible)
        ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(
      p,
      6.5,
      Paint()..color = AppColors.primary.withValues(alpha: visible),
    );
    canvas.drawCircle(
      p,
      3.0,
      Paint()..color = Colors.white.withValues(alpha: visible),
    );
  }

  /// La ruta viva. Va en la banda de arriba, como una línea de horizonte:
  /// la marca queda debajo en las tres pantallas —el splash la centra, el
  /// login y la bienvenida la suben— y ninguna la cruza.
  Path _rutaA(Size s) => Path()
    ..moveTo(-30, s.height * 0.205)
    ..cubicTo(
      s.width * 0.20,
      s.height * 0.198,
      s.width * 0.24,
      s.height * 0.068,
      s.width * 0.52,
      s.height * 0.080,
    )
    ..cubicTo(
      s.width * 0.78,
      s.height * 0.090,
      s.width * 0.76,
      s.height * 0.198,
      s.width + 30,
      s.height * 0.158,
    );

  Path _rutaB(Size s) => Path()
    ..moveTo(s.width * 0.14, -20)
    ..cubicTo(
      s.width * 0.06,
      s.height * 0.16,
      s.width * 0.30,
      s.height * 0.24,
      s.width * 0.24,
      s.height * 0.46,
    );

  Path _rutaC(Size s) => Path()
    ..moveTo(s.width + 20, s.height * 0.06)
    ..cubicTo(
      s.width * 0.72,
      s.height * 0.06,
      s.width * 0.86,
      s.height * 0.36,
      s.width * 0.66,
      s.height * 0.44,
    );

  @override
  bool shouldRepaint(covariant _RedDeRutasPainter old) =>
      old.showUser != showUser || old.avance != avance || old.haloY != haloY;
}
