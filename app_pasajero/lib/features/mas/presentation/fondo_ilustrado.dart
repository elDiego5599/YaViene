import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  // Solo los buses de las empresas que están en la app: uno de Transmetro
  // o de Sodis prometería rutas que no hay (revisión externa, 2026-10-18).
  busSobusa('info_sobusa'),
  busCoolitoral('info_coolitoral');

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
/// el matizado del arranque. Atenuados y sin relleno en los huecos («atenúa
/// un poco las imágenes», dueño, 2026-10-18): son fondo, lo que se lee son
/// las tarjetas blancas de encima. Solo arriba, detrás de la marca, y se
/// apagan hacia las tarjetas: en toda la pantalla hacían ruido (revisión
/// externa, 2026-10-18). Quieto.
class FondoIlustrado extends StatelessWidget {
  const FondoIlustrado({super.key, required this.child});

  final Widget child;

  /// Lo mínimo entre los centros de dos dibujos: deja al menos 10 pt entre
  /// los dos más grandes, y unos 45 en un teléfono de 390 × 844.
  static const double separacion = 70;

  /// Lado base del cuadro de cada dibujo; varía de 0,85 a 1,15 (44–60 pt).
  static const double _lado = 52;

  /// Cuánto se ven los dibujos: vivos, con su color (dueño, 2026-10-18: al
  /// 40 % la página «quedó demasiado opaca»), sin pelearle a las tarjetas,
  /// que son blancas y opacas.
  static const double velo = 0.72;

  /// Hasta dónde llegan los dibujos, por debajo de la barra de estado: se
  /// ven enteros detrás de la marca y se apagan sobre la tarjeta de la ruta,
  /// que en un teléfono va de 98 a 214 desde ahí.
  static const double franja = 200;

  /// Hasta dónde se ven enteros: la píldora de la marca acaba en 76.
  static const double _enteros = 80;

  /// El degradado con que se apagan en una caja de [caja], para [arriba]
  /// de barra de estado.
  static LinearGradient desvanecido(Size caja, {double arriba = 0}) {
    double donde(double y) => ((arriba + y) / caja.height).clamp(0.0, 1.0);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Colors.white, Colors.white, Color(0x00FFFFFF)],
      stops: [0, donde(_enteros), donde(franja)],
    );
  }

  /// Giro máximo, a cada lado.
  static const double _giro = 15;

  /// Cuánto sale cada uno frente a los demás: un bus por cada tres de lo
  /// otro.
  static int _peso(Motivo m) => _esBus(m) ? 1 : 3;

  static bool _esBus(Motivo m) => m.name.startsWith('bus');

  /// Los dibujos de una pantalla de [pantalla], de arriba hasta la
  /// [franja] bajo [arriba] de barra de estado, también un poco por fuera
  /// de las orillas para que nada quede cortado en seco. Siempre los
  /// mismos: la semilla es fija.
  static List<Celda> celdas(Size pantalla, {double arriba = 0}) {
    final azar = math.Random(18);
    final usos = {for (final m in Motivo.values) m: 0};
    final celdas = <Celda>[];
    final hasta = arriba + franja;
    for (final centro
        in regar(azar, pantalla, 8, separacion, aparte: (p) => p.dy > hasta)) {
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
    final arriba = MediaQuery.paddingOf(context).top;
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
                // Un solo velo para todos: una capa, no una por dibujo.
                Positioned.fill(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (r) =>
                        desvanecido(r.size, arriba: arriba).createShader(r),
                    child: Opacity(
                      opacity: velo,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final c in celdas(caja.biggest, arriba: arriba))
                            _dibujo(c),
                        ],
                      ),
                    ),
                  ),
                ),
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
