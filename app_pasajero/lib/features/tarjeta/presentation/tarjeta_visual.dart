import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// La proporción de una tarjeta de verdad (ISO/IEC 7810 ID-1, 85,6 × 54 mm).
const _proporcionTarjeta = 85.6 / 54;

/// Lo que pasa en el aire, en tres tiempos: la tarjeta llega con resorte, se
/// queda quieta un momento y un destello la cruza una sola vez.
const _duracionTotal = Duration(milliseconds: 1700);
const _finLlegada = 0.36;
const _inicioBrillo = 0.5;

/// La tarjeta SIBUS dibujada: la ciudad de noche sobre el degradado de la
/// marca, el símbolo sin contacto y una banda blanca con los cuatro últimos
/// dígitos en tinta, como el número impreso de la de verdad.
///
/// No copia el arte oficial del AMB: es la tarjeta de Ya Viene que la
/// representa, como Wallet dibuja un pase sin la foto de la tarjeta.
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

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({required this.ultimos4, required this.brillo});

  final String? ultimos4;
  final double brillo;

  /// Alto de la banda blanca: dos líneas (caption y número) con aire.
  static const _banda = 64.0;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(AppRadius.card);
    return AspectRatio(
      aspectRatio: _proporcionTarjeta,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: forma,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDeep, AppColors.acento],
          ),
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
            children: [
              // Un brillo suave arriba a la derecha: relieve sin foto.
              Positioned(
                right: -60,
                top: -80,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // La ciudad, sentada sobre la banda.
              const Positioned(
                left: 0,
                right: 0,
                bottom: _banda,
                height: 78,
                child: CustomPaint(painter: _HorizontePintor()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SIBUS',
                            style: AppTextStyles.titulo.copyWith(
                              color: Colors.white,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Barranquilla',
                            style: AppTextStyles.pie.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.contactless_outlined,
                      size: 30,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _banda,
                child: _Banda(ultimos4: ultimos4),
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
}

/// La banda blanca de abajo: su filo verde, el número en tinta con cifras de
/// ancho fijo (no baila al escribir) y el bus de la marca.
class _Banda extends StatelessWidget {
  const _Banda({required this.ultimos4});

  final String? ultimos4;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(
            height: 3,
            width: double.infinity,
            child: ColoredBox(color: AppColors.primary),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 18, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Número',
                          style: AppTextStyles.pie
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            ultimos4 == null ? '•••• ••••' : '•••• $ultimos4',
                            style: AppTextStyles.titulo.copyWith(
                              color: AppColors.textPrimary,
                              letterSpacing: 2,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.successLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      size: 20,
                      color: AppColors.primaryAccessible,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La silueta de la ciudad: manzanas de alturas distintas con algunas
/// ventanas encendidas. Fija (nada al azar) para que cada render sea igual.
class _HorizontePintor extends CustomPainter {
  const _HorizontePintor();

  // Izquierda, ancho y alto, todo como fracción del lienzo.
  static const _edificios = <(double, double, double)>[
    (0.02, 0.10, 0.45),
    (0.12, 0.08, 0.75),
    (0.20, 0.12, 0.55),
    (0.32, 0.07, 1.00),
    (0.39, 0.11, 0.60),
    (0.50, 0.09, 0.85),
    (0.59, 0.12, 0.50),
    (0.71, 0.08, 0.70),
    (0.79, 0.11, 0.90),
    (0.90, 0.08, 0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final masa = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final luz = Paint()..color = Colors.white.withValues(alpha: 0.34);
    for (final (izquierda, ancho, alto) in _edificios) {
      final x = izquierda * size.width;
      final w = ancho * size.width;
      final h = alto * size.height;
      canvas.drawRect(Rect.fromLTWH(x, size.height - h, w, h), masa);
      // Ventanas de 3 × 4 pt cada 8 × 9 pt; encendidas, una de cada cuatro.
      var fila = 0;
      for (var y = size.height - h + 8; y < size.height - 6; y += 9) {
        var columna = 0;
        for (var cx = x + 5; cx + 3 < x + w - 3; cx += 8) {
          if ((fila * 3 + columna * 5 + (izquierda * 100).round()) % 4 == 0) {
            canvas.drawRect(Rect.fromLTWH(cx, y, 3, 4), luz);
          }
          columna++;
        }
        fila++;
      }
    }
  }

  @override
  bool shouldRepaint(_HorizontePintor viejo) => false;
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
