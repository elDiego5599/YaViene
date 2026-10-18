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
/// pantalla»; y luego «es demasiado, reduce la cantidad de buses sobre
/// todo, y todo con el mismo orden no cuadra»): dibujos chicos de
/// Barranquilla regados sin orden, con aire entre ellos, cada uno algo
/// girado y de su tamaño, sin dos iguales juntos y con pocos buses, sobre
/// el matizado del arranque y con puntitos, estrellitas y espirales en los
/// huecos. Quieto; las tarjetas blancas van por encima.
class FondoIlustrado extends StatelessWidget {
  const FondoIlustrado({super.key, required this.child});

  final Widget child;

  /// Lo mínimo entre los centros de dos dibujos: deja al menos 10 pt entre
  /// los dos más grandes, y unos 45 en un teléfono de 390 × 844.
  static const double separacion = 70;

  /// Lado base del cuadro de cada dibujo; varía de 0,85 a 1,15 (44–60 pt).
  static const double _lado = 52;

  /// Giro máximo, a cada lado.
  static const double _giro = 15;

  /// Cuánto sale cada uno frente a los demás: un bus por cada tres de lo
  /// otro, así entre los cuatro buses son uno de cada cinco dibujos.
  static int _peso(Motivo m) => _esBus(m) ? 1 : 3;

  static bool _esBus(Motivo m) => m.name.startsWith('bus');

  /// Los dibujos de una pantalla de [pantalla], también un poco por fuera
  /// de las orillas para que nada quede cortado en seco. Siempre los
  /// mismos: la semilla es fija.
  static List<Celda> celdas(Size pantalla) {
    final azar = math.Random(18);
    final usos = {for (final m in Motivo.values) m: 0};
    final celdas = <Celda>[];
    for (final centro in regar(azar, pantalla, 8, separacion)) {
      final vecinos = {
        for (final c in celdas)
          if ((c.centro - centro).distance <= separacion * 1.5) c.motivo,
      };
      // Un bus no va junto a otro bus, salvo que no quede más remedio.
      final hayBus = vecinos.any(_esBus);
      var libres = Motivo.values.where((m) => !vecinos.contains(m));
      if (hayBus && libres.any((m) => !_esBus(m))) {
        libres = libres.where((m) => !_esBus(m));
      }
      double cuota(Motivo m) => usos[m]! / _peso(m);
      final menos = libres.map(cuota).reduce(math.min);
      final candidatos = libres.where((m) => cuota(m) == menos).toList();
      final motivo = candidatos[azar.nextInt(candidatos.length)];
      usos[motivo] = usos[motivo]! + 1;
      celdas.add((
        motivo: motivo,
        centro: centro,
        lado: _lado * (0.85 + azar.nextDouble() * 0.3),
        giro: (azar.nextDouble() * 2 - 1) * _giro,
      ));
    }
    return celdas;
  }

  /// Puntos regados al azar sobre [pantalla] (y [distancia] por fuera), a
  /// no menos de [distancia] entre ellos ni de lo que [aparte] rechace, y
  /// sin calvas: se prueba cada punto de una rejilla de [paso] en desorden,
  /// así que donde cabía uno más, quedó.
  static List<Offset> regar(
    math.Random azar,
    Size pantalla,
    double paso,
    double distancia, {
    bool Function(Offset)? aparte,
  }) {
    final rejilla = [
      for (var y = -distancia; y <= pantalla.height + distancia; y += paso)
        for (var x = -distancia; x <= pantalla.width + distancia; x += paso)
          Offset(x, y),
    ]..shuffle(azar);
    final puestos = <Offset>[];
    for (final p in rejilla) {
      if (aparte != null && aparte(p)) continue;
      if (puestos.every((q) => (q - p).distance >= distancia)) puestos.add(p);
    }
    return puestos;
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
/// de la marca: regados igual que ellos, en lo que queda libre.
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
    final dibujos = FondoIlustrado.celdas(pantalla);
    // Fuera del cuadro del dibujo más grande (30 de medio lado) y su aire.
    bool encima(Offset p) => dibujos.any((c) => (c.centro - p).distance < 36);
    return [
      for (final centro
          in FondoIlustrado.regar(azar, pantalla, 6, 24, aparte: encima))
        (
          tipo: Relleno.values[azar.nextInt(Relleno.values.length)],
          centro: centro,
          color: _colores[azar.nextInt(_colores.length)],
          giro: azar.nextDouble() * 2 * math.pi,
        ),
    ];
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
