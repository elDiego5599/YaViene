import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../splash/presentation/widgets/escena_arranque.dart';
import '../../splash/presentation/widgets/fondo_matizado.dart';

/// Los dibujos de Barranquilla del fondo de Info. La Ventana al Mundo no es
/// foto: es la torre del arranque, ya armada (dueño, 2026-10-18).
enum Motivo {
  cayena('info_flor'),
  sol('info_sol'),
  palmera('info_palmera'),
  marimonda('info_marimonda'),
  ventana(null),
  busSobusa('info_sobusa'),
  busCoolitoral('info_coolitoral'),
  busTransmetro('info_transmetro'),
  busSodis('info_sodis');

  const Motivo(this._archivo);

  final String? _archivo;

  String? get asset => _archivo == null ? null : 'assets/images/$_archivo.webp';
}

/// Un dibujo puesto: dónde cae su centro, de qué lado es su cuadro y cuánto
/// gira, en grados.
typedef Celda = ({Motivo motivo, Offset centro, double lado, double giro});

/// El fondo de Info (dueño, 2026-10-18: «mucho más pequeños, en toda la
/// pantalla, con más buses diferentes y más de cada cosa»): un papel de
/// dibujos chicos de Barranquilla en hileras corridas, cada uno algo
/// girado y de su tamaño, sin dos iguales juntos, sobre el matizado del
/// arranque y con puntitos, estrellitas y espirales en los huecos. Quieto;
/// las tarjetas blancas van por encima.
class FondoIlustrado extends StatelessWidget {
  const FondoIlustrado({super.key, required this.child});

  final Widget child;

  /// Distancia entre dibujos de una hilera; las hileras van a √3/2 de ella
  /// y corridas media celda, así los seis vecinos quedan a la misma
  /// distancia y no se abre una calle vacía.
  static const double celda = 64;
  static const double _fila = celda * 0.875;

  /// Lado base del cuadro de cada dibujo; varía de 0,85 a 1,15 (44–60 pt).
  static const double _lado = 52;

  /// Giro máximo, a cada lado.
  static const double _giro = 15;

  /// Corrimiento máximo del centro, para que no se vea cuadriculado.
  static const double _corrimiento = 6;

  /// Los dibujos de una pantalla de [pantalla], con una hilera y una
  /// columna de más por cada orilla para que nada quede cortado en seco.
  /// Siempre los mismos: la semilla es fija.
  static List<Celda> celdas(Size pantalla) {
    final azar = math.Random(18);
    final columnas = (pantalla.width / celda).ceil() + 2;
    final filas = (pantalla.height / _fila).ceil() + 2;
    final puestos = <(int, int), Motivo>{};
    final usos = {for (final m in Motivo.values) m: 0};
    final celdas = <Celda>[];
    for (var f = -1; f < filas; f++) {
      final impar = f.isOdd;
      for (var c = -1; c < columnas; c++) {
        // Los vecinos ya puestos: el de la izquierda y los dos de arriba.
        final arriba = impar ? [c, c + 1] : [c - 1, c];
        final vecinos = {
          puestos[(f, c - 1)],
          for (final a in arriba) puestos[(f - 1, a)],
        };
        final libres =
            Motivo.values.where((m) => !vecinos.contains(m)).toList();
        final menos = libres.map((m) => usos[m]!).reduce(math.min);
        final candidatos = libres.where((m) => usos[m] == menos).toList();
        final motivo = candidatos[azar.nextInt(candidatos.length)];
        puestos[(f, c)] = motivo;
        usos[motivo] = usos[motivo]! + 1;
        double centrado() => (azar.nextDouble() * 2 - 1) * _corrimiento;
        celdas.add((
          motivo: motivo,
          centro: Offset(
            c * celda + (impar ? celda / 2 : 0) + centrado(),
            f * _fila + centrado(),
          ),
          lado: _lado * (0.85 + azar.nextDouble() * 0.3),
          giro: (azar.nextDouble() * 2 - 1) * _giro,
        ));
      }
    }
    return celdas;
  }

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
                const Positioned.fill(
                  child: CustomPaint(painter: PintorRelleno()),
                ),
                for (final c in celdas(caja.biggest)) _dibujo(c),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _dibujo(Celda c) {
    final asset = c.motivo.asset;
    return Positioned.fromRect(
      rect: Rect.fromCenter(center: c.centro, width: c.lado, height: c.lado),
      child: Transform.rotate(
        angle: c.giro * math.pi / 180,
        child: asset == null
            ? Center(
                child: SizedBox(
                  width: c.lado * PintorVentana.aspecto,
                  height: c.lado,
                  child: CustomPaint(painter: PintorVentana(1)),
                ),
              )
            : Image.asset(
                asset,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                filterQuality: FilterQuality.medium,
              ),
      ),
    );
  }
}

/// Lo que va en los huecos entre dibujos.
enum Relleno { punto, estrella, espiral }

/// Un adorno del relleno, con su giro en radianes.
typedef PiezaRelleno = ({
  Relleno tipo,
  Offset centro,
  Color color,
  double giro,
});

/// Los puntitos, estrellitas y espirales entre los dibujos, en los colores
/// de la marca: uno en cada triángulo que dejan tres dibujos vecinos, que
/// es donde más lejos queda cualquiera de ellos.
class PintorRelleno extends CustomPainter {
  const PintorRelleno();

  static const List<Color> _colores = [
    AppColors.acento,
    AppColors.primary,
    AppColors.coral,
    AppColors.warning,
  ];

  static List<PiezaRelleno> piezas(Size pantalla) {
    final azar = math.Random(81);
    const celda = FondoIlustrado.celda;
    const fila = FondoIlustrado._fila;
    final columnas = (pantalla.width / celda).ceil() + 2;
    final filas = (pantalla.height / fila).ceil() + 2;
    final piezas = <PiezaRelleno>[];
    for (var f = -1; f < filas; f++) {
      final x0 = f.isOdd ? celda / 2 : 0.0;
      for (var c = -1; c < columnas; c++) {
        // Los dos triángulos que tienen por lado a este dibujo y al de su
        // derecha: su centro está a media celda y a un tercio de hilera.
        for (final lado in const [-1, 1]) {
          double corrido() => (azar.nextDouble() * 2 - 1) * 3;
          piezas.add((
            tipo: Relleno.values[azar.nextInt(Relleno.values.length)],
            centro: Offset(
              c * celda + x0 + celda / 2 + corrido(),
              f * fila + lado * fila / 3 + corrido(),
            ),
            color: _colores[azar.nextInt(_colores.length)],
            giro: azar.nextDouble() * 2 * math.pi,
          ));
        }
      }
    }
    return piezas;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lleno = Paint()..isAntiAlias = true;
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final p in piezas(size)) {
      final color = p.color.withValues(alpha: 0.85);
      canvas
        ..save()
        ..translate(p.centro.dx, p.centro.dy)
        ..rotate(p.giro);
      switch (p.tipo) {
        case Relleno.punto:
          canvas.drawCircle(Offset.zero, 3, lleno..color = color);
        case Relleno.estrella:
          canvas.drawPath(_estrella(5.5), lleno..color = color);
        case Relleno.espiral:
          canvas.drawPath(_espiral(6), trazo..color = color);
      }
      canvas.restore();
    }
  }

  static Path _estrella(double r) {
    final camino = Path();
    for (var i = 0; i < 10; i++) {
      final radio = i.isEven ? r : r * 0.45;
      final a = i * math.pi / 5 - math.pi / 2;
      final punto = Offset(math.cos(a) * radio, math.sin(a) * radio);
      i == 0
          ? camino.moveTo(punto.dx, punto.dy)
          : camino.lineTo(punto.dx, punto.dy);
    }
    return camino..close();
  }

  /// Una vuelta y media que se abre del centro hacia [r].
  static Path _espiral(double r) {
    final camino = Path()..moveTo(0, 0);
    const pasos = 24;
    for (var i = 1; i <= pasos; i++) {
      final t = i / pasos;
      final a = t * 3 * math.pi;
      camino.lineTo(math.cos(a) * r * t, math.sin(a) * r * t);
    }
    return camino;
  }

  @override
  bool shouldRepaint(PintorRelleno antes) => false;
}
