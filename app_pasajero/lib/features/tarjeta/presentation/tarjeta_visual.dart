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
/// líneas de rutas a 45 grados, la leyenda en blanco a la derecha y una franja
/// blanca abajo. Sin número impreso: estas tarjetas no lo llevan a la vista.
///
/// No copia los logos del AMB ni de la Alcaldía: la franja lleva solo el bus
/// de Ya Viene.
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

  /// Margen y alto de la franja blanca de abajo.
  static const _margen = 10.0;
  static const _franja = 34.0;

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
          child: Stack(
            fit: StackFit.expand,
            children: [
              // El degradado diagonal: amarillo arriba a la izquierda, naranja
              // y rojo hacia abajo a la derecha; el verde entra por la
              // esquina de arriba a la derecha.
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
              // El rectángulo verde translúcido de arriba a la derecha.
              Positioned(
                top: 0,
                right: 26,
                width: 58,
                height: 46,
                child: ColoredBox(color: _verde.withValues(alpha: 0.55)),
              ),
              const Positioned.fill(
                child:
                    IgnorePointer(child: CustomPaint(painter: _RutasPintor())),
              ),
              Positioned(
                right: 18,
                top: 0,
                bottom: _franja + _margen * 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'TARJETA INTELIGENTE\nPARA TRANSPORTE\n'
                    'DEL ÁREA METROPOLITANA\nDE BARRANQUILLA',
                    textAlign: TextAlign.right,
                    // Tinta impresa: no crece con el texto grande.
                    textScaler: TextScaler.noScaling,
                    style: leyenda,
                  ),
                ),
              ),
              const Positioned(
                left: _margen,
                right: _margen,
                bottom: _margen,
                height: _franja,
                child: _Franja(),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _DestelloPintor(brillo)),
                ),
              ),
            ],
          ),
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

/// La franja blanca redondeada de abajo. Los logos del AMB y de la Alcaldía
/// no los tenemos con permiso: lleva solo el bus de Ya Viene.
class _Franja extends StatelessWidget {
  const _Franja();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.successLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.directions_bus_rounded,
            size: 15,
            color: AppColors.primaryAccessible,
          ),
        ),
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
