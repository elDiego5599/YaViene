import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// La proporción de una tarjeta de verdad (ISO/IEC 7810 ID-1, 85,6 × 54 mm).
const _proporcionTarjeta = 85.6 / 54;

/// Lo que pasa en el aire, en tres tiempos: la tarjeta llega con resorte, se
/// queda quieta un momento y un destello la cruza una sola vez.
const _duracionTotal = Duration(milliseconds: 1700);
const _finLlegada = 0.36;
const _inicioBrillo = 0.5;

/// La tarjeta SIBUS dibujada como la de verdad: degradado diagonal de
/// amarillo, verde y naranja a rojo, la ciudad de fondo con poca opacidad,
/// líneas de rutas a 45 grados, la leyenda en blanco abajo a la izquierda y
/// una franja blanca abajo. Sin número impreso: estas tarjetas no lo llevan
/// a la vista.
///
/// La franja lleva los logos oficiales del AMB, de SIBUS y de la Alcaldía de
/// Barranquilla, que el dueño entregó (`assets/tarjeta/`).
///
/// [ultimos4] solo alimenta la etiqueta de accesibilidad.
class TarjetaVisual extends StatefulWidget {
  const TarjetaVisual({super.key, this.ultimos4});

  final String? ultimos4;

  @override
  State<TarjetaVisual> createState() => _TarjetaVisualState();
}

class _TarjetaVisualState extends State<TarjetaVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control =
      AnimationController(vsync: this, duration: _duracionTotal);

  @override
  void initState() {
    super.initState();
    _control.forward();
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quieta = MediaQuery.disableAnimationsOf(context);
    final digitos = widget.ultimos4;
    return Semantics(
      container: true,
      label: digitos == null
          ? 'Tu tarjeta SIBUS'
          : 'Tarjeta SIBUS terminada en $digitos',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _control,
          builder: (context, _) {
            // Con «reducir movimiento» la tarjeta ya está en su sitio; el
            // destello es luz, no desplazamiento, y se queda.
            final llegada = quieta
                ? 1.0
                : AppMotion.curvaRebote
                    .transform((_control.value / _finLlegada).clamp(0.0, 1.0));
            final brillo = Curves.easeInOut.transform(
              ((_control.value - _inicioBrillo) / (1 - _inicioBrillo))
                  .clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: quieta ? 1 : llegada.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - llegada)),
                child: Transform.scale(
                  scale: 0.94 + 0.06 * llegada,
                  child: _Cuerpo(brillo: brillo),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

const _fondo = 'assets/tarjeta/fondo_ciudad.jpg';

/// Los tonos de la tarjeta de verdad: amarillo intenso arriba a la izquierda,
/// verde arriba a la derecha y, abajo, naranja que se hace rojo.
const _amarillo = Color(0xFFF5E000);
const _verde = Color(0xFF3DAA35);
const _naranja = Color(0xFFE8501E);
const _rojo = Color(0xFFD9261C);

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({required this.brillo});

  final double brillo;

  /// La franja blanca, en proporciones de la tarjeta de verdad (medidas de
  /// una foto): ancho de margen lateral, alto, y el hueco que deja abajo
  /// (ahí va la letra pequeña, que no dibujamos).
  static const _margenLateral = 0.06;
  static const _altoFranja = 0.17;
  static const _huecoAbajo = 0.06;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(AppRadius.card);
    final leyenda = AppTextStyles.pie.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
      height: 1.25,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 4,
        ),
      ],
    );
    return AspectRatio(
      aspectRatio: _proporcionTarjeta,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: forma,
          color: _naranja,
          boxShadow: [
            BoxShadow(
              color: _rojo.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: forma,
          child: LayoutBuilder(builder: (context, caja) {
            final lateral = caja.maxWidth * _margenLateral;
            final franja = caja.maxHeight * _altoFranja;
            final abajo = caja.maxHeight * _huecoAbajo;
            return Stack(
              fit: StackFit.expand,
              children: [
                // El degradado diagonal: amarillo arriba a la izquierda,
                // naranja y rojo hacia abajo a la derecha; el verde entra
                // por la esquina de arriba a la derecha.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_amarillo, _naranja, _rojo],
                      stops: [0.1, 0.62, 1.0],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(1.05, -1.1),
                      radius: 1.15,
                      colors: [_verde, Color(0x003DAA35)],
                    ),
                  ),
                ),
                // La ciudad, en grises y con poca opacidad, solo en la franja
                // del centro: se funde arriba y abajo con el degradado.
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00FFFFFF),
                      Color(0xFFFFFFFF),
                      Color(0xFFFFFFFF),
                      Color(0x00FFFFFF),
                    ],
                    stops: [0.12, 0.38, 0.66, 0.9],
                  ).createShader(rect),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(_grises),
                    child: Opacity(
                      opacity: 0.3,
                      child: Image.asset(
                        _fondo,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0.2, 0.1),
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                      child: CustomPaint(painter: _RutasPintor())),
                ),
                Positioned(
                  left: lateral,
                  bottom: abajo + franja + caja.maxHeight * 0.04,
                  child: Text(
                    'TARJETA INTELIGENTE\nPARA TRANSPORTE\n'
                    'DEL ÁREA METROPOLITANA\nDE BARRANQUILLA',
                    textAlign: TextAlign.left,
                    // Tinta impresa: no crece con el texto grande.
                    textScaler: TextScaler.noScaling,
                    style: leyenda,
                  ),
                ),
                Positioned(
                  left: lateral,
                  right: lateral,
                  bottom: abajo,
                  height: franja,
                  child: const _Franja(),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _DestelloPintor(brillo)),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// Luminancia sola: la foto pierde su color para que mande el degradado.
  static const _grises = <double>[
    0.30, 0.59, 0.11, 0, 0, //
    0.30, 0.59, 0.11, 0, 0,
    0.30, 0.59, 0.11, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// La franja blanca de abajo con los tres logos, como la tarjeta de verdad:
/// un rectángulo bajo de esquinas apenas redondeadas, con AMB a la izquierda,
/// SIBUS al centro y la Alcaldía a la derecha, pequeños y con mucho blanco
/// alrededor (cada uno ocupa tres cuartos del alto de la franja).
class _Franja extends StatelessWidget {
  const _Franja();

  static const _logoAmb = 'assets/tarjeta/logo_amb.png';
  static const _logoSibus = 'assets/tarjeta/logo_sibus.jpg';
  static const _logoAlcaldia = 'assets/tarjeta/logo_alcaldia_barranquilla.png';

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: LayoutBuilder(
        builder: (context, caja) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: caja.maxWidth * 0.05,
            vertical: caja.maxHeight * 0.14,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Logo(_logoAmb),
              _Logo(_logoSibus),
              _Logo(_logoAlcaldia),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo(this.ruta);

  final String ruta;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Image.asset(
        ruta,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Las líneas finas amarillo claro de la derecha, como un mapa de rutas o un
/// circuito: trazos rectos que giran en ángulos de 45 grados, con un punto
/// en cada extremo.
class _RutasPintor extends CustomPainter {
  const _RutasPintor();

  /// Cada ruta, en fracciones del ancho y del alto: arranca y avanza por
  /// tramos horizontales, verticales o diagonales de 45 grados.
  static const _rutas = <List<Offset>>[
    [
      Offset(0.50, 0.20),
      Offset(0.62, 0.20),
      Offset(0.68, 0.14),
      Offset(0.78, 0.14)
    ],
    [Offset(0.80, 0.22), Offset(0.80, 0.12), Offset(0.86, 0.06)],
    [
      Offset(0.58, 0.60),
      Offset(0.72, 0.60),
      Offset(0.79, 0.53),
      Offset(0.98, 0.53)
    ],
    [
      Offset(0.66, 0.70),
      Offset(0.78, 0.70),
      Offset(0.85, 0.63),
      Offset(0.98, 0.63)
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..color = const Color(0xFFFFF59D).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;
    final punto = Paint()..color = trazo.color;
    for (final ruta in _rutas) {
      final puntos = [
        for (final o in ruta) Offset(o.dx * size.width, o.dy * size.height),
      ];
      canvas.drawPath(
        Path()..addPolygon(puntos, false),
        trazo,
      );
      canvas.drawCircle(puntos.first, 2, punto);
      canvas.drawCircle(puntos.last, 2, punto);
    }
  }

  @override
  bool shouldRepaint(_RutasPintor viejo) => false;
}

/// El destello que cruza la tarjeta de izquierda a derecha, en diagonal.
class _DestelloPintor extends CustomPainter {
  const _DestelloPintor(this.progreso);

  final double progreso;

  @override
  void paint(Canvas canvas, Size size) {
    if (progreso <= 0 || progreso >= 1) return;
    const ancho = 70.0;
    const inclinacion = 36.0;
    final x = -ancho -
        inclinacion +
        (size.width + 2 * (ancho + inclinacion)) * progreso;
    final trazo = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(x, 0, ancho + inclinacion, size.height));
    canvas.drawPath(
      Path()
        ..moveTo(x + inclinacion, 0)
        ..lineTo(x + inclinacion + ancho, 0)
        ..lineTo(x + ancho, size.height)
        ..lineTo(x, size.height)
        ..close(),
      trazo,
    );
  }

  @override
  bool shouldRepaint(_DestelloPintor viejo) => viejo.progreso != progreso;
}
