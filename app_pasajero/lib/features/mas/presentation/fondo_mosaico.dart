import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../splash/presentation/widgets/escena_arranque.dart';

/// Los dibujos del mosaico de Info.
enum Motivo {
  ventana,
  cayena,
  sobusa,
  marimonda,
  coolitoral,
  sol,
  sodetrans,
  palmera,
  transmetro,
  puente,
}

/// El fondo de Info (dueño, 2026-10-18: «como un mosaico de todas estas
/// imágenes de buses, flores y la ventana, tipo Cartoon Doodle Wall»): una
/// pared de dibujos de línea con lo de Barranquilla, en tonos claros sobre
/// un papel casi blanco. Quieto (el movimiento queda para el arranque) y
/// pintado una sola vez. Lo que se lee encima va en blanco: las tarjetas y
/// las píldoras de la marca y los créditos (`test/fondo_mosaico_test.dart`).
class FondoMosaico extends StatelessWidget {
  const FondoMosaico({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Aparte: al desplazar las tarjetas no se vuelve a pintar la pared.
        const RepaintBoundary(
          child: CustomPaint(painter: PintorMosaico(), size: Size.infinite),
        ),
        child,
      ],
    );
  }
}

/// La pared entera. Siempre la misma: cada celda saca su giro de su sitio.
class PintorMosaico extends CustomPainter {
  const PintorMosaico();

  /// El paso de la cuadrícula y el tamaño de cada dibujo: lo bastante
  /// grandes para reconocerlos, lo bastante chicos para que en un teléfono
  /// quepan los diez más de una vez.
  static const double celda = 92;
  static const double dibujo = 56;

  static const _papel = Color(0xFFF8FAFB);

  /// Cada celda con su dibujo y su centro. Las filas van corridas media
  /// celda, como ladrillos, y el orden avanza uno por columna y tres por
  /// fila: así ningún vecino, ni el de al lado ni el de arriba ni los de la
  /// diagonal, repite dibujo.
  static Iterable<(Motivo, Offset)> celdas(Size size) sync* {
    final filas = (size.height / celda).ceil() + 1;
    final columnas = (size.width / celda).ceil() + 1;
    for (var f = 0; f < filas; f++) {
      final corrida = f.isOdd ? celda / 2 : 0.0;
      for (var c = -1; c < columnas; c++) {
        final i = (c + 3 * f) % Motivo.values.length;
        yield (
          Motivo.values[i],
          Offset(celda * 0.5 + c * celda + corrida, celda * 0.45 + f * celda),
        );
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _papel);
    for (final (motivo, centro) in celdas(size)) {
      final azar = math.Random(centro.dx.round() * 31 + centro.dy.round());
      canvas
        ..save()
        ..translate(centro.dx, centro.dy)
        ..rotate((azar.nextDouble() - 0.5) * 0.36);
      final escala = 0.9 + azar.nextDouble() * 0.15;
      canvas.scale(escala);
      _Doodle(canvas, dibujo).pinta(motivo);
      canvas.restore();
      // Los rellenos entre dibujos: una chispa, un punto o un garabato.
      _relleno(canvas, centro + const Offset(celda / 2, celda / 2),
          azar.nextInt(3), azar);
    }
  }

  static const _rellenos = [
    Color(0xFFF2C4C0),
    Color(0xFFBFD6EF),
    Color(0xFFBFE5CF),
    Color(0xFFF5DE9C),
  ];

  void _relleno(Canvas canvas, Offset c, int tipo, math.Random azar) {
    final color = _rellenos[azar.nextInt(_rellenos.length)];
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    switch (tipo) {
      case 0: // chispa de cuatro puntas
        const r = 6.0;
        final p = Path()
          ..moveTo(c.dx, c.dy - r)
          ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
          ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
        canvas.drawPath(p, Paint()..color = color);
      case 1: // tres puntos
        final p = Paint()..color = color;
        canvas
          ..drawCircle(c + const Offset(-6, 2), 2.2, p)
          ..drawCircle(c + const Offset(0, -3), 2.2, p)
          ..drawCircle(c + const Offset(6, 2), 2.2, p);
      default: // garabato
        final p = Path()..moveTo(c.dx - 9, c.dy);
        for (var i = 0; i < 3; i++) {
          final x = c.dx - 9 + i * 6;
          p.quadraticBezierTo(x + 1.5, c.dy + (i.isEven ? -5 : 5), x + 6, c.dy);
        }
        canvas.drawPath(p, trazo);
    }
  }

  @override
  bool shouldRepaint(PintorMosaico antes) => false;
}

/// Un dibujo de línea en una caja de [s] centrada en el origen: relleno
/// pastel y contorno de su mismo tono, más hondo.
class _Doodle {
  _Doodle(this.canvas, this.s);

  final Canvas canvas;
  final double s;

  Paint _linea(Color c, [double ancho = 2]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = ancho
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _lleno(Color c) => Paint()..color = c;

  void _forma(Path p, Color relleno, Color trazo) {
    canvas
      ..drawPath(p, _lleno(relleno))
      ..drawPath(p, _linea(trazo));
  }

  void pinta(Motivo m) => switch (m) {
        Motivo.ventana => _ventana(),
        Motivo.cayena => _cayena(),
        Motivo.sobusa => _bus(
            cuerpo: const Color(0xFFC4E7D2),
            trazo: const Color(0xFF6BB892),
            franjas: const [Color(0xFFF3B3AD), Color(0xFFF6DD94)],
          ),
        Motivo.coolitoral => _bus(
            cuerpo: const Color(0xFFCBEBD8),
            trazo: const Color(0xFF6BB892),
            franjas: const [Color(0xFFF0A9A3)],
            franjaAncha: true,
          ),
        Motivo.sodetrans => _bus(
            cuerpo: Colors.white,
            trazo: const Color(0xFF8DADDB),
            franjas: const [Color(0xFFBCD2F0), Color(0xFFD5E3F6)],
          ),
        Motivo.transmetro => _bus(
            cuerpo: const Color(0xFFC3CCE2),
            trazo: const Color(0xFF8C9BC0),
            franjas: const [Color(0xFFBFE5CF)],
            articulado: true,
          ),
        Motivo.marimonda => _marimonda(),
        Motivo.palmera => _palmera(),
        Motivo.sol => _sol(),
        Motivo.puente => _puente(),
      };

  /// La Ventana al Mundo: la torre partida en dos puntas, con su cuadrícula
  /// de colores.
  void _ventana() {
    final w = s * 0.42, h = s * 0.5;
    final torre = Path()
      ..moveTo(-w, h)
      ..lineTo(-w, -h * 0.85)
      ..lineTo(-w * 0.05, -h * 0.6)
      ..lineTo(w, -h)
      ..lineTo(w * 0.8, h)
      ..close();
    canvas.drawPath(torre, _lleno(Colors.white));
    canvas.save();
    canvas.clipPath(torre);
    const tonos = [
      Color(0xFFF5BDB8),
      Color(0xFFF7D9A0),
      Color(0xFFF6EDA6),
      Color(0xFFC3E6CF),
      Color(0xFFBCD6F0),
      Color(0xFFD4C8EE),
    ];
    final paso = s * 0.14;
    for (var f = 0; f < 8; f++) {
      for (var c = 0; c < 7; c++) {
        if ((f + c) % 3 == 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(-w + c * paso, -h + f * paso, paso, paso).deflate(1),
          _lleno(tonos[(f + c ~/ 2) % tonos.length]),
        );
      }
    }
    canvas.restore();
    canvas.drawPath(torre, _linea(const Color(0xFF8DADDB)));
    // La ventana del medio.
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(-w * 0.3, -h * 0.2), width: s * 0.2, height: s * 0.26),
      _lleno(Colors.white),
    );
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(-w * 0.3, -h * 0.2), width: s * 0.2, height: s * 0.26),
      _linea(const Color(0xFF8DADDB), 1.6),
    );
  }

  /// La cayena: los cinco pétalos sueltos del arranque
  /// ([PintorCayena.petalo]), en pastel, y la columna que sube sobre el de
  /// arriba con su polen y sus estigmas.
  void _cayena() {
    const rojo = Color(0xFFF6BDB8);
    const trazo = Color(0xFFE48A82);
    final r = s * 0.5;
    final petalo = PintorCayena.petalo(r);
    for (var i = 0; i < 5; i++) {
      canvas
        ..save()
        ..rotate(i * 2 * math.pi / 5);
      _forma(petalo, rojo, trazo);
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, r * 0.16, _lleno(const Color(0xFFEFA39C)));
    final punta = Offset(-r * 0.04, -r * 0.66);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(r * 0.05, -r * 0.34, punta.dx, punta.dy),
      _linea(trazo, 1.8),
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(i.isEven ? -r * 0.08 : r * 0.08, -r * (0.4 + i * 0.05)),
        1.8,
        _lleno(const Color(0xFFF2CF5B)),
      );
    }
    for (final a in const [-0.6, 0.0, 0.6]) {
      canvas.drawCircle(punta + Offset(math.sin(a), -math.cos(a)) * r * 0.08,
          1.6, _lleno(trazo));
    }
  }

  /// Un bus de lado: carrocería redonda, la fila de ventanas, sus franjas
  /// y dos ruedas. El Transmetro va articulado.
  void _bus({
    required Color cuerpo,
    required Color trazo,
    required List<Color> franjas,
    bool franjaAncha = false,
    bool articulado = false,
  }) {
    final w = s * (articulado ? 0.56 : 0.48), h = s * 0.27;
    final caja = RRect.fromRectAndRadius(
        Rect.fromLTRB(-w, -h, w, h * 0.78), Radius.circular(s * 0.08));
    canvas.drawRRect(caja, _lleno(cuerpo));
    canvas.save();
    canvas.clipRRect(caja);
    for (final (i, color) in franjas.indexed) {
      final alto = franjaAncha ? h * 0.42 : h * 0.16;
      final y = h * 0.22 + i * (alto + 2);
      final franja = Path()
        ..moveTo(-w, y + alto)
        ..lineTo(-w, y)
        ..quadraticBezierTo(0, y - h * 0.18, w, y + h * 0.05)
        ..lineTo(w, y + h * 0.05 + alto)
        ..quadraticBezierTo(0, y + alto - h * 0.18, -w, y + alto)
        ..close();
      canvas.drawPath(franja, _lleno(color));
    }
    canvas.restore();
    canvas.drawRRect(caja, _linea(trazo));
    // Las ventanas, y el parabrisas al frente (a la derecha).
    final vidrio = _lleno(const Color(0xFFE7F1FB));
    final borde = _linea(trazo, 1.5);
    final n = articulado ? 5 : 4;
    final ancho = (w * 2 - s * 0.2) / (n + 1);
    for (var i = 0; i < n; i++) {
      final v = RRect.fromRectAndRadius(
        Rect.fromLTWH(-w + s * 0.06 + i * (ancho + s * 0.015), -h * 0.72, ancho,
            h * 0.62),
        Radius.circular(s * 0.054),
      );
      canvas
        ..drawRRect(v, vidrio)
        ..drawRRect(v, borde);
    }
    final frente = RRect.fromRectAndRadius(
      Rect.fromLTRB(w - ancho - s * 0.03, -h * 0.72, w - s * 0.04, h * 0.05),
      Radius.circular(s * 0.054),
    );
    canvas
      ..drawRRect(frente, vidrio)
      ..drawRRect(frente, borde);
    if (articulado) {
      canvas.drawLine(Offset(-w * 0.12, -h), Offset(-w * 0.12, h * 0.78),
          _linea(trazo, 1.5));
    }
    // Ruedas.
    for (final x in [-w * 0.55, w * 0.55]) {
      final c = Offset(x, h * 0.8);
      canvas
        ..drawCircle(c, s * 0.075, _lleno(Colors.white))
        ..drawCircle(c, s * 0.075, _linea(trazo))
        ..drawCircle(c, s * 0.022, _lleno(trazo));
    }
  }

  /// La marimonda del Carnaval: orejas grandes, ojos redondos y la nariz
  /// larga que cuelga.
  void _marimonda() {
    const trazo = Color(0xFFD1A54C);
    final r = s * 0.24;
    for (final lado in [-1.0, 1.0]) {
      final oreja = Path()
        ..addOval(Rect.fromCenter(
            center: Offset(lado * r * 1.25, -r * 0.35),
            width: r * 1.05,
            height: r * 1.3));
      _forma(oreja, const Color(0xFFBFD6EF), const Color(0xFF8DADDB));
    }
    final cara = Path()
      ..addOval(Rect.fromCenter(
          center: Offset.zero, width: r * 1.9, height: r * 2.1));
    _forma(cara, const Color(0xFFF8E3A8), trazo);
    for (final lado in [-1.0, 1.0]) {
      final ojo = Offset(lado * r * 0.42, -r * 0.35);
      canvas
        ..drawCircle(ojo, r * 0.28, _lleno(Colors.white))
        ..drawCircle(ojo, r * 0.28, _linea(trazo, 1.6))
        ..drawCircle(ojo, r * 0.1, _lleno(const Color(0xFF9AAACC)));
    }
    final nariz = Path()
      ..moveTo(-r * 0.16, -r * 0.1)
      ..quadraticBezierTo(-r * 0.2, r * 1.1, r * 0.5, r * 1.5)
      ..quadraticBezierTo(r * 0.75, r * 1.55, r * 0.7, r * 1.3)
      ..quadraticBezierTo(r * 0.15, r * 1.05, r * 0.16, -r * 0.1)
      ..close();
    _forma(nariz, const Color(0xFFF3B3AD), const Color(0xFFE48A82));
    // Las rayas de colores de la frente.
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(-r * 0.5 + i * r * 0.5, -r * 0.95),
        Offset(-r * 0.4 + i * r * 0.4, -r * 0.75),
        _linea(const [
          Color(0xFFE48A82),
          Color(0xFF6BB892),
          Color(0xFF8DADDB),
        ][i]),
      );
    }
  }

  /// La palmera: tronco curvo y cinco hojas que caen.
  void _palmera() {
    const trazoHoja = Color(0xFF6BB892);
    final tronco = Path()
      ..moveTo(-s * 0.06, s * 0.48)
      ..quadraticBezierTo(s * 0.02, s * 0.05, s * 0.12, -s * 0.2)
      ..lineTo(s * 0.18, -s * 0.18)
      ..quadraticBezierTo(s * 0.1, s * 0.08, s * 0.06, s * 0.48)
      ..close();
    _forma(tronco, const Color(0xFFEBD8B4), const Color(0xFFC9A36E));
    final copa = Offset(s * 0.15, -s * 0.22);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi * 0.95 + i * math.pi * 0.47;
      final punta =
          copa + Offset(math.cos(a), math.sin(a) * 0.6 + 0.35) * s * 0.36;
      final medio =
          copa + Offset(math.cos(a), math.sin(a) * 0.6 - 0.3) * s * 0.22;
      final hoja = Path()
        ..moveTo(copa.dx, copa.dy)
        ..quadraticBezierTo(medio.dx, medio.dy - 5, punta.dx, punta.dy)
        ..quadraticBezierTo(medio.dx, medio.dy + 5, copa.dx, copa.dy)
        ..close();
      _forma(hoja, const Color(0xFFC4E7D2), trazoHoja);
    }
    canvas
      ..drawCircle(
          copa + const Offset(-3, 4), 3.2, _lleno(const Color(0xFFD9B98A)))
      ..drawCircle(
          copa + const Offset(3, 5), 3.2, _lleno(const Color(0xFFD9B98A)));
  }

  /// El sol de la costa, con su cara.
  void _sol() {
    const trazo = Color(0xFFE5B44E);
    final r = s * 0.22;
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
          d * r * 1.3, d * r * (i.isEven ? 1.9 : 1.65), _linea(trazo, 2.2));
    }
    _forma(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)),
        const Color(0xFFF9E7A7), trazo);
    canvas
      ..drawCircle(Offset(-r * 0.35, -r * 0.15), 1.8, _lleno(trazo))
      ..drawCircle(Offset(r * 0.35, -r * 0.15), 1.8, _lleno(trazo))
      ..drawArc(Rect.fromCircle(center: Offset(0, r * 0.1), radius: r * 0.45),
          0.3, math.pi - 0.6, false, _linea(trazo, 1.6));
  }

  /// El Puente Pumarejo: el tablero sobre el río, la torre y sus tirantes en
  /// abanico.
  void _puente() {
    const trazo = Color(0xFF8DADDB);
    final w = s * 0.52;
    // El río.
    for (var i = 0; i < 2; i++) {
      final y = s * 0.3 + i * 7;
      final ola = Path()..moveTo(-w * 0.8, y);
      for (var k = 0; k < 4; k++) {
        final x = -w * 0.8 + k * w * 0.4;
        ola.quadraticBezierTo(x + w * 0.1, y - 3, x + w * 0.2, y);
        ola.quadraticBezierTo(x + w * 0.3, y + 3, x + w * 0.4, y);
      }
      canvas.drawPath(ola, _linea(const Color(0xFFBCD2F0), 1.8));
    }
    final torre = Path()
      ..moveTo(-s * 0.05, s * 0.18)
      ..lineTo(-s * 0.03, -s * 0.46)
      ..lineTo(s * 0.03, -s * 0.46)
      ..lineTo(s * 0.05, s * 0.18)
      ..close();
    _forma(torre, Colors.white, trazo);
    final tirante = _linea(const Color(0xFFA9C1E5), 1.3);
    for (var i = 1; i <= 4; i++) {
      final x = w * i / 4.4;
      final arriba = Offset(0, -s * 0.42 + i * s * 0.05);
      canvas
        ..drawLine(arriba, Offset(x, s * 0.08), tirante)
        ..drawLine(arriba, Offset(-x, s * 0.08), tirante);
    }
    final tablero = RRect.fromRectAndRadius(
        Rect.fromLTRB(-w, s * 0.06, w, s * 0.14), Radius.circular(s * 0.036));
    canvas
      ..drawRRect(tablero, _lleno(const Color(0xFFD5E3F6)))
      ..drawRRect(tablero, _linea(trazo));
  }
}
