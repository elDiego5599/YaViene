import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// La proporción de una tarjeta de verdad (ISO/IEC 7810 ID-1, 85,6 × 54 mm).
const _proporcionTarjeta = 85.6 / 54;

/// Lo que pasa en el aire, en tres tiempos: la tarjeta llega con resorte, se
/// queda quieta un momento y un destello la cruza una sola vez.
const _duracionTotal = Duration(milliseconds: 1700);
const _finLlegada = 0.36;
const _inicioBrillo = 0.5;

/// La tarjeta SIBUS dibujada como la de verdad: una foto aérea de la ciudad
/// (la Ventana al Mundo) teñida con el degradado verde, amarillo y naranja,
/// la leyenda en blanco y una franja blanca con el código de barras y el
/// número impreso diminuto a su lado, no grande como en una bancaria.
///
/// No copia los logos del AMB ni de la Alcaldía: la franja lleva el bus de Ya
/// Viene y un código de barras genérico. Evoca la tarjeta sin imitar marcas.
///
/// Con [ultimos4] nulo muestra los puntos vacíos: es la vista previa viva
/// del campo donde el pasajero todavía está escribiendo el número.
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
                  child: _Cuerpo(ultimos4: digitos, brillo: brillo),
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

/// Los tres tonos de la tarjeta de verdad, del verde de abajo a la izquierda
/// al naranja de arriba a la derecha.
const _verde = AppColors.primary;
const _amarillo = Color(0xFFFFD21F);
const _naranja = Color(0xFFFF7A1A);

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({required this.ultimos4, required this.brillo});

  final String? ultimos4;
  final double brillo;

  /// Alto de la franja blanca de abajo.
  static const _franja = 54.0;

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
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 4,
        ),
      ],
    );
    return AspectRatio(
      aspectRatio: _proporcionTarjeta,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: forma,
          color: _verde,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.28),
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
              // La foto en grises, multiplicada por el degradado: así queda
              // teñida y sigue viéndose la ciudad, como en la de verdad.
              ShaderMask(
                blendMode: BlendMode.multiply,
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [_verde, _amarillo, _naranja],
                  stops: [0.0, 0.52, 1.0],
                ).createShader(rect),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(_grisesClaros),
                  child: Image.asset(
                    _fondo,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.55, -0.2),
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              // Un velo abajo para que la leyenda blanca se lea sobre
              // cualquier parte de la foto.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x59000000)],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                bottom: _franja + 14,
                width: 190,
                child: Text(
                  'TARJETA INTELIGENTE PARA TRANSPORTE DEL ÁREA '
                  'METROPOLITANA DE BARRANQUILLA',
                  style: leyenda,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _franja,
                child: _Franja(ultimos4: ultimos4),
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

  /// Grises con luz: la foto pasa a luminancia y se aclara un poco para que
  /// el degradado multiplicado no se vea sucio.
  static const _grisesClaros = <double>[
    0.30, 0.59, 0.11, 0, 40, //
    0.30, 0.59, 0.11, 0, 40,
    0.30, 0.59, 0.11, 0, 40,
    0, 0, 0, 1, 0,
  ];
}

/// La franja blanca de abajo: el bus de la marca, el número impreso diminuto
/// y un código de barras genérico.
class _Franja extends StatelessWidget {
  const _Franja({required this.ultimos4});

  final String? ultimos4;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                size: 17,
                color: AppColors.primaryAccessible,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _BarrasPintor(ultimos4 ?? ''),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ultimos4 == null ? '•••• ••••' : '•••• $ultimos4',
                    style: AppTextStyles.pie.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: (AppTextStyles.pie.fontSize ?? 12) * 0.8,
                      letterSpacing: 1.2,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un código de barras genérico (no codifica nada): los anchos salen de los
/// dígitos que se ven, para que cada tarjeta tenga el suyo y siempre el mismo.
class _BarrasPintor extends CustomPainter {
  const _BarrasPintor(this.semilla);

  final String semilla;

  @override
  void paint(Canvas canvas, Size size) {
    final tinta = Paint()..color = AppColors.textPrimary;
    final base = semilla.isEmpty ? '40817293' : semilla;
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final d = int.parse(base[i % base.length]) + i * 3;
      final barra = 1.0 + (d % 3);
      final hueco = 1.0 + ((d ~/ 3) % 3);
      final ancho = (x + barra > size.width) ? size.width - x : barra;
      canvas.drawRect(Rect.fromLTWH(x, 0, ancho, size.height), tinta);
      x += barra + hueco;
      i++;
    }
  }

  @override
  bool shouldRepaint(_BarrasPintor viejo) => viejo.semilla != semilla;
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
