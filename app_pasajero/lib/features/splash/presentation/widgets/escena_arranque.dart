import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/widgets/ink_hero.dart';

/// La escena del arranque (dueño, 2026-10-18): Barranquilla se arma sobre
/// blanco y el bus llega. La Ventana al Mundo se enciende en ola, de abajo
/// arriba, sobre su isla de pasto con arbustos; la cayena abre sus cinco
/// pétalos; el bus (sin empresa: Ya Viene es de todas) viene de lejos y
/// frena de frente («ya viene»); y queda la marca.
///
/// Breve a propósito (dueño: «2 segundos es mucho»): [duracion] entera,
/// con las piezas solapadas. Con «Reducir movimiento» se pinta ya armada y
/// quieta. La torre y la flor van dibujadas aquí, no en imagen, para que
/// cada cuadrito y cada pétalo se animen por su cuenta y salgan nítidos a
/// cualquier densidad.
class EscenaArranque extends StatefulWidget {
  const EscenaArranque({super.key, this.alTerminar});

  /// Avisa cuando la escena quedó armada.
  final VoidCallback? alTerminar;

  /// Lo armado tarda 1,2 s, como antes; después la marca se queda quieta
  /// [lecturaMarca] para leerla (dueño, 2026-10-18: «que dure un
  /// poquitito más cuando aparece el texto»).
  static const Duration duracion = Duration(milliseconds: 1700);

  /// Lo que la marca se queda entera antes de pasar a la bienvenida.
  static const Duration lecturaMarca = Duration(milliseconds: 500);

  /// El lado de la cayena en la escena de 300.
  static const double ladoFlor = 112;

  /// Lo que dura armada y quieta con «Reducir movimiento», para que la
  /// marca se alcance a leer.
  static const Duration quieta = Duration(milliseconds: 700);

  // Los tramos de cada pieza, en milisegundos sobre los 1.700 de
  // [duracion]: los mismos tiempos que cuando la escena duraba 1.250.
  static const torre = Interval(0, 687 / 1700);
  static const flor =
      Interval(275 / 1700, 975 / 1700, curve: Curves.easeOutBack);
  static const bus = Interval(475 / 1700, 1075 / 1700);
  static const marca =
      Interval(825 / 1700, 1200 / 1700, curve: Curves.easeOutCubic);

  @override
  State<EscenaArranque> createState() => _EscenaArranqueState();
}

class _EscenaArranqueState extends State<EscenaArranque>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: EscenaArranque.duracion);
  bool _empezo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_empezo) return;
    _empezo = true;
    if (AppMotion.reducido(context)) {
      _c.value = 1;
      Future<void>.delayed(EscenaArranque.quieta, () {
        if (mounted) widget.alTerminar?.call();
      });
      return;
    }
    _c.forward().whenCompleteOrCancel(() {
      if (mounted) widget.alTerminar?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Abriendo Ya Viene',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 300,
                  height: 300,
                  child: _escena(t),
                ),
                const SizedBox(height: 28),
                _marca(EscenaArranque.marca.transform(t)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _escena(double t) {
    final torre = EscenaArranque.torre.transform(t);
    final flor = EscenaArranque.flor.transform(t);
    final bus = EscenaArranque.bus.transform(t);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // La torre, a la izquierda del centro (torre y flor juntas quedan
        // centradas: de 48 a 252): 290 de alto y su ancho propio
        // (655 × 1755 en el dibujo de referencia).
        Positioned(
          left: 48,
          top: 0,
          width: 290 * PintorVentana.aspecto,
          height: 290,
          child: CustomPaint(painter: PintorVentana(torre)),
        ),
        // El suelo (dueño, 2026-10-18: «como su suelo con arbusticos»): una
        // isla de pasto donde se paran la torre y la flor, delante del pie
        // de la torre, que queda sembrada, y detrás del bus.
        Positioned(
          left: 10,
          right: 10,
          top: 250,
          height: 56,
          child: CustomPaint(painter: PintorSuelo(torre)),
        ),
        // La cayena, delante del filo derecho de la torre. De 112: a 136
        // «se ve muy grande» (dueño, 2026-10-18).
        Positioned(
          left: 140,
          top: 140,
          width: EscenaArranque.ladoFlor,
          height: EscenaArranque.ladoFlor,
          child: CustomPaint(painter: PintorCayena(flor)),
        ),
        // El bus, delante de todo, al pie.
        Positioned(
          left: 0,
          right: 0,
          bottom: -6,
          child: Center(child: _bus(bus)),
        ),
      ],
    );
  }

  /// El bus viene de lejos hacia quien mira: crece desde chico y baja un
  /// poco (se acerca), y al llegar cabecea al frenar.
  Widget _bus(double p) {
    final llegada = Curves.easeOutCubic.transform((p / 0.82).clamp(0.0, 1.0));
    final freno = p <= 0.82 ? 0.0 : math.sin((p - 0.82) / 0.18 * math.pi);
    final escala = 0.18 + 0.82 * llegada;
    return Opacity(
      opacity: (p / 0.2).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, -46 * (1 - llegada) + 2 * freno),
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform:
              Matrix4.diagonal3Values(escala, escala * (1 - 0.03 * freno), 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/arranque_bus.webp',
                width: 104,
                filterQuality: FilterQuality.medium,
              ),
              // La sombra en el piso.
              Transform.translate(
                offset: const Offset(0, -4),
                child: Container(
                  width: 92,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.all(Radius.elliptical(46, 4)),
                    color: AppColors.ink.withValues(alpha: 0.10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.12),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _marca(double m) {
    return Opacity(
      opacity: m.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - m)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // El logo vuela a la bienvenida, como antes (mismo `Hero`).
            Hero(
              tag: InkHero.marcaHeroTag,
              child: SvgPicture.asset(
                'assets/icon/ya_viene_logo.svg',
                width: 40,
                height: 40,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Ya Viene',
              style: AppTextStyles.marca.copyWith(color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// La Ventana al Mundo: la cara de enfrente, de rojo arriba a azul abajo,
/// con su ventana; y la de un lado, en azules. Cada cuadrito se prende en
/// ola de abajo arriba según [avance] (0 a 1).
class PintorVentana extends CustomPainter {
  PintorVentana(this.avance);

  final double avance;

  /// Ancho entre alto del dibujo de referencia.
  static const double aspecto = 655 / 1755;

  // Las caras, en fracción del recuadro (medidas sobre la referencia).
  static const _frente = [
    Offset(0, 0.026),
    Offset(0.702, 0.108),
    Offset(0.74, 1),
    Offset(0.153, 1),
  ];
  static const _lado = [
    Offset(0.573, 0.088),
    Offset(0.962, 0),
    Offset(1, 0.034),
    Offset(0.786, 1),
    Offset(0.74, 1),
    Offset(0.702, 0.108),
  ];
  static const _ventana = Rect.fromLTRB(0.305, 0.151, 0.623, 0.332);

  static const _filas = 22;

  // De arriba abajo, como en el monumento.
  static const _coloresFrente = [
    Color(0xFFE8262B),
    Color(0xFFF26A1B),
    Color(0xFFF7A21B),
    Color(0xFFF9D71C),
    Color(0xFFA8C92A),
    Color(0xFF2FA35B),
    Color(0xFFC9EBB8),
    Color(0xFF7CC8DF),
    Color(0xFF1E7FC2),
    Color(0xFF2B4A8B),
  ];
  static const _coloresLado = [
    Color(0xFF3E4FA0),
    Color(0xFF7B7FD6),
    Color(0xFF29A9C9),
    Color(0xFFC9EBB8),
    Color(0xFF2FA35B),
    Color(0xFFF9D71C),
    Color(0xFFE8262B),
  ];

  static const _apagado = Color(0xFFEDEFF2);
  static const _junta = Color(0xFF20242B);

  /// El alto al que se dibujó: las juntas y el marco engrosan o adelgazan
  /// con el dibujo, si no, chica en Info, las juntas tapan los colores.
  static const double _altoBase = 290;

  Path _poligono(List<Offset> puntos, Size s) => Path()
    ..addPolygon(
        [for (final p in puntos) Offset(p.dx * s.width, p.dy * s.height)],
        true);

  void _cara(Canvas canvas, Size s, List<Offset> forma, double x0, double x1,
      int columnas, List<Color> colores, int semilla) {
    final borde = _poligono(forma, s);
    final azar = math.Random(semilla);
    canvas.save();
    canvas.clipPath(borde);
    final ancho = (x1 - x0) * s.width / columnas;
    final alto = s.height / _filas;
    final escala = s.height / _altoBase;
    final junta = Paint()
      ..color = _junta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 * escala;
    for (var f = 0; f < _filas; f++) {
      final altura = f / (_filas - 1);
      for (var c = 0; c < columnas; c++) {
        // El color sigue la altura, con un vecino al azar para que se vea
        // a mano, como el de la torre de verdad.
        final i =
            ((altura + (azar.nextDouble() - 0.5) * 0.16) * (colores.length - 1))
                .round()
                .clamp(0, colores.length - 1);
        // La ola sube: abajo se prende primero.
        final desde = 0.55 * (1 - altura) + 0.12 * azar.nextDouble();
        final luz =
            Curves.easeOut.transform(((avance - desde) / 0.3).clamp(0.0, 1.0));
        final celda =
            Rect.fromLTWH(x0 * s.width + c * ancho, f * alto, ancho, alto);
        final lleno = Rect.fromCenter(
          center: celda.center,
          width: celda.width * (0.7 + 0.3 * luz),
          height: celda.height * (0.7 + 0.3 * luz),
        );
        canvas.drawRect(celda, Paint()..color = _apagado);
        if (luz > 0) {
          canvas.drawRect(
              lleno, Paint()..color = Color.lerp(_apagado, colores[i], luz)!);
        }
        canvas.drawRect(celda, junta);
      }
    }
    canvas.restore();
    canvas.drawPath(
        borde,
        Paint()
          ..color = _junta
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * escala
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // La silueta asoma de una vez y sube un poco mientras se prende.
    final asoma =
        Curves.easeOutCubic.transform((avance / 0.25).clamp(0.0, 1.0));
    canvas.saveLayer(
        Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, asoma));
    final escala = size.height / _altoBase;
    canvas.translate(0, 14 * escala * (1 - asoma));
    _cara(canvas, size, _lado, 0.70, 1, 4, _coloresLado, 7);
    _cara(canvas, size, _frente, 0, 0.74, 9, _coloresFrente, 3);
    // La ventana: el marco y el concreto de adentro.
    final v = Rect.fromLTRB(
        _ventana.left * size.width,
        _ventana.top * size.height,
        _ventana.right * size.width,
        _ventana.bottom * size.height);
    canvas.drawRect(v, Paint()..color = const Color(0xFFB9B4AC));
    canvas.drawPath(
      Path()
        ..moveTo(v.left, v.top)
        ..lineTo(v.right, v.top)
        ..lineTo(v.right, v.top + v.height * 0.45)
        ..lineTo(v.left + v.width * 0.42, v.top + v.height * 0.45)
        ..lineTo(v.left + v.width * 0.42, v.bottom)
        ..lineTo(v.left, v.bottom)
        ..close(),
      Paint()..color = const Color(0xFF8E8A84),
    );
    canvas.drawRect(
        v,
        Paint()
          ..color = const Color(0xFFD6D2CB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * escala);
    canvas.drawRect(
        v.inflate(1.2 * escala),
        Paint()
          ..color = _junta
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 * escala);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PintorVentana antes) => antes.avance != avance;
}

/// El suelo de la escena: una isla de pasto con su canto de tierra, el
/// mismo contorno oscuro de la torre, una calle de frente al centro por
/// donde llega el bus (dueño, 2026-10-18: «donde está el bus, en el centro,
/// haz como una calle» y «que se vea de frente, todo más bonito y
/// detallado», con la raya del medio blanca) y sus arbustos con hojas y
/// florecitas. Asoma con la torre según [avance] (0 a 1): la isla crece
/// desde su centro y los arbustos brotan uno tras otro, con su rebote.
class PintorSuelo extends CustomPainter {
  PintorSuelo(this.avance);

  final double avance;

  /// Los arbustos, por (centro en fracción del ancho, tamaño relativo):
  /// dos a cada lado de la calle, el de dentro más chico.
  static const _matas = [
    (0.09, 1.0),
    (0.27, 0.8),
    (0.73, 0.85),
    (0.92, 1.05),
  ];

  static int get arbustos => _matas.length;

  /// La calle: por dónde corre al frente, en fracción del ancho. El bus de
  /// 104 va centrado en la isla de 280, de 0,314 a 0,686, y la calle le
  /// deja una orilla a cada lado. Va de frente: simétrica, se angosta hacia
  /// atrás y su raya del medio sube derecha.
  static const (double, double) calle = (0.29, 0.71);
  static const (double, double) _calleAtras = (0.455, 0.545);

  static const _pasto = Color(0xFF94D167);
  static const _pastoHondo = Color(0xFF5DAE4E);
  static const _canto = Color(0xFF3E8E45);
  static const _cantoHondo = Color(0xFF2F7439);
  static const _brizna = Color(0xFF4C9E46);
  static const _briznaClara = Color(0xFFCDEB8E);
  static const _hoja = Color(0xFF2FA35B);
  static const _hojaClara = Color(0xFF6CC060);
  static const _hojaOscura = Color(0xFF1F7A43);
  static const _brillo = Color(0xFFB4DE76);
  static const _flor = Color(0xFFE8262B);
  static const _centro = Color(0xFFF9D71C);
  static const _asfalto = Color(0xFF6A7077);
  static const _asfaltoHondo = Color(0xFF50565D);
  static const _asfaltoCanto = Color(0xFF484D54);
  static const _bordillo = Color(0xFFE4E1DA);
  static const _bordilloCara = Color(0xFFB9B4AB);
  static const _raya = Colors.white;
  static const _junta = Color(0xFF20242B);

  /// Lo que mide el canto de la isla, en fracción del alto.
  static const double _grueso = 0.09;

  /// Dónde arranca la calle atrás, en fracción del alto: en el borde de la
  /// isla, a la derecha del pie de la torre.
  static const double _arriba = 0.3;

  /// La altura del borde de arriba de la isla en [x] (0 a 1): sube al
  /// centro, donde se paran la torre y la flor.
  static double _borde(double x) => 0.72 - 0.3 * math.sin(math.pi * x);

  @override
  void paint(Canvas canvas, Size size) {
    if (avance <= 0) return;
    final w = size.width, h = size.height;
    final escala = h / 56;
    final crece =
        Curves.easeOutCubic.transform((avance / 0.35).clamp(0.0, 1.0));
    final contorno = Paint()
      ..color = _junta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * escala
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(w / 2, h * 0.75);
    canvas.scale(crece, crece);
    canvas.translate(-w / 2, -h * 0.75);
    final isla = Path()..moveTo(0, _borde(0) * h);
    for (var i = 1; i <= 40; i++) {
      final x = i / 40;
      isla.lineTo(x * w, _borde(x) * h);
    }
    isla
      ..cubicTo(w * 1.01, h * 0.98, w * 0.8, h * 0.99, w / 2, h * 0.99)
      ..cubicTo(w * 0.2, h * 0.99, -w * 0.01, h * 0.98, 0, _borde(0) * h)
      ..close();
    // La cara de arriba es la isla sin su canto: lo que queda de ella
    // corrida hacia arriba.
    final cara = Path.combine(
        PathOperation.intersect, isla, isla.shift(Offset(0, -_grueso * h)));
    canvas
      ..drawPath(
          isla,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_canto, _cantoHondo],
            ).createShader(Rect.fromLTRB(0, h * 0.8, w, h)))
      ..drawPath(
          cara,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(0, -0.9),
              radius: 1.1,
              colors: [_pasto, _pastoHondo],
            ).createShader(Offset.zero & size));
    _briznas(canvas, size, cara, escala);
    _calle(canvas, size, isla, cara, escala);
    canvas
      ..drawPath(
          cara,
          Paint()
            ..color = _junta
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6 * escala)
      ..drawPath(isla, contorno);
    canvas.restore();

    for (var i = 0; i < _matas.length; i++) {
      final (x, t) = _matas[i];
      final p = Curves.easeOutBack
          .transform(((avance - 0.25 - 0.08 * i) / 0.35).clamp(0.0, 1.0));
      if (p <= 0) continue;
      _arbusto(canvas, Offset(x * w, _borde(x) * h + 2 * escala),
          12 * escala * t, p, escala, i + 1, contorno);
    }
  }

  /// La textura del pasto: rayitas finas desparejas, claras atrás y
  /// hondas al frente, y la sombra del pie de la torre.
  void _briznas(Canvas canvas, Size size, Path cara, double escala) {
    final w = size.width, h = size.height;
    canvas.save();
    canvas.clipPath(cara);
    canvas.drawOval(
        Rect.fromLTRB(0.17 * w, 0.18 * h, 0.5 * w, 0.42 * h),
        Paint()
          ..color = _canto.withValues(alpha: 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.4 * escala));
    final azar = math.Random(11);
    for (var i = 0; i < 160; i++) {
      final x = azar.nextDouble();
      final y = _borde(x) + (0.95 - _borde(x)) * azar.nextDouble();
      final cerca = ((y - 0.42) / 0.5).clamp(0.0, 1.0);
      final largo = (1.0 + 1.6 * cerca + azar.nextDouble()) * escala;
      final ladeo = (azar.nextDouble() - 0.5) * 1.4 * escala;
      final base = Offset(x * w, y * h);
      canvas.drawLine(
          base,
          base + Offset(ladeo, -largo),
          Paint()
            ..color = (azar.nextDouble() > cerca ? _briznaClara : _brizna)
                .withValues(alpha: 0.5 + 0.35 * azar.nextDouble())
            ..strokeWidth = 0.6 * escala
            ..strokeCap = StrokeCap.round);
    }
    canvas.restore();
  }

  /// La calle, de frente: asfalto con su grano que se oscurece al
  /// acercarse, bordillos claros con su cara a cada orilla, la raya blanca
  /// del medio en trazos que se alargan al frente, y su corte en el canto.
  void _calle(Canvas canvas, Size size, Path isla, Path cara, double escala) {
    final w = size.width, h = size.height;
    final (l, r) = calle;
    final (la, ra) = _calleAtras;
    double x(double atras, double frente, double y) =>
        (atras + (frente - atras) * (y - _arriba) / (1 - _arriba)) * w;
    Offset orilla(double atras, double frente, double y) =>
        Offset(x(atras, frente, y), y * h);
    Path franja(double desdeAtras, double desdeFrente, double hastaAtras,
            double hastaFrente) =>
        Path()
          ..moveTo(x(desdeAtras, desdeFrente, _arriba), _arriba * h)
          ..lineTo(x(hastaAtras, hastaFrente, _arriba), _arriba * h)
          ..lineTo(x(hastaAtras, hastaFrente, 1.02), 1.02 * h)
          ..lineTo(x(desdeAtras, desdeFrente, 1.02), 1.02 * h)
          ..close();
    final via = franja(la, l, ra, r);
    final arriba = Rect.fromLTRB(0, _arriba * h, w, h);

    // En el canto, la calle corta la tierra: asfalto hondo.
    canvas.save();
    canvas.clipPath(Path.combine(PathOperation.difference, isla, cara));
    canvas.drawPath(via, Paint()..color = _asfaltoCanto);
    canvas.restore();

    canvas.save();
    canvas.clipPath(cara);
    canvas.drawPath(
        via,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_asfalto, _asfaltoHondo],
          ).createShader(arriba));
    // El grano del asfalto.
    canvas.save();
    canvas.clipPath(via);
    final azar = math.Random(3);
    final grano = Paint();
    for (var i = 0; i < 90; i++) {
      final y = _arriba + (1 - _arriba) * azar.nextDouble();
      final px = x(l, l, 0) + (x(r, r, 0) - x(l, l, 0)) * azar.nextDouble();
      canvas.drawCircle(
          Offset(px, y * h),
          (0.25 + 0.35 * azar.nextDouble()) * escala,
          grano
            ..color = (azar.nextBool() ? Colors.white : _junta)
                .withValues(alpha: 0.08));
    }
    canvas.restore();
    // Los bordillos: un filo claro y, hacia la calle, su cara en sombra.
    const ancho = 0.022, frenteBordillo = 0.012;
    for (final lado in [-1, 1]) {
      final (atras, frente) = lado < 0 ? (la, l) : (ra, r);
      final afuera = franja(
          atras - ancho * lado * 0.5, frente - ancho * lado, atras, frente);
      final adentro = franja(atras, frente, atras + frenteBordillo * lado * 0.5,
          frente + frenteBordillo * lado);
      canvas
        ..drawPath(adentro, Paint()..color = _bordilloCara)
        ..drawPath(afuera, Paint()..color = _bordillo);
      final filo = Paint()
        ..color = _junta
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7 * escala;
      canvas
        ..drawLine(
            orilla(atras - ancho * lado * 0.5, frente - ancho * lado, _arriba),
            orilla(atras - ancho * lado * 0.5, frente - ancho * lado, 1.02),
            filo)
        ..drawLine(
            orilla(atras + frenteBordillo * lado * 0.5,
                frente + frenteBordillo * lado, _arriba),
            orilla(atras + frenteBordillo * lado * 0.5,
                frente + frenteBordillo * lado, 1.02),
            filo);
    }
    // La raya del medio: derecha, en trazos que crecen al acercarse.
    final raya = Paint()..color = _raya;
    var y = _arriba + 0.06;
    while (y < 1) {
      final largo = 0.04 + 0.12 * (y - _arriba);
      final fin = math.min(y + largo, 1.02);
      final media = (0.7 + 1.3 * (y - _arriba)) * escala;
      final mediaFin = (0.7 + 1.3 * (fin - _arriba)) * escala;
      canvas.drawPath(
          Path()
            ..moveTo(w / 2 - media, y * h)
            ..lineTo(w / 2 + media, y * h)
            ..lineTo(w / 2 + mediaFin, fin * h)
            ..lineTo(w / 2 - mediaFin, fin * h)
            ..close(),
          raya);
      y = fin + largo * 0.8;
    }
    canvas.restore();
  }

  /// Un arbusto: tres bolas apretadas, sombreado de la luz a lo hondo, con
  /// hojitas claras arriba a la izquierda y oscuras abajo, el pliegue entre
  /// bola y bola, su sombra en el pasto y dos cayenitas de cinco pétalos.
  void _arbusto(Canvas canvas, Offset base, double r, double p, double escala,
      int semilla, Paint contorno) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(p);
    canvas.drawOval(
        Rect.fromLTRB(-1.5 * r, -0.25 * r, 1.7 * r, 0.3 * r),
        Paint()
          ..color = _canto.withValues(alpha: 0.75)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.4 * escala));
    final bolas = [
      Rect.fromCircle(center: Offset(-0.75 * r, -0.55 * r), radius: 0.8 * r),
      Rect.fromCircle(center: Offset(0.75 * r, -0.5 * r), radius: 0.75 * r),
      Rect.fromCircle(center: Offset(0, -1.0 * r), radius: r),
    ];
    final mata = Path();
    for (final b in bolas) {
      mata.addOval(b);
    }
    final silueta = Path.combine(PathOperation.union, mata,
        Path()..addRect(Rect.fromLTRB(-1.4 * r, -0.6 * r, 1.4 * r, 0)));
    final recorte = Path.combine(PathOperation.intersect, silueta,
        Path()..addRect(Rect.fromLTRB(-2 * r, -3 * r, 2 * r, 0)));
    canvas.drawPath(
        recorte,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_hojaClara, _hoja, _hojaOscura],
          ).createShader(Rect.fromLTRB(-1.5 * r, -2 * r, 1.5 * r, 0)));
    canvas.save();
    canvas.clipPath(recorte);
    final azar = math.Random(semilla);
    for (var i = 0; i < 26; i++) {
      final hx = (azar.nextDouble() * 2.8 - 1.4) * r;
      final hy = -azar.nextDouble() * 2 * r;
      final sol = (-hx / r - hy / r * 0.5) > 0.4;
      canvas.save();
      canvas
        ..translate(hx, hy)
        ..rotate(azar.nextDouble() * math.pi);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: 0.36 * r, height: 0.18 * r),
          Paint()
            ..color = (sol ? _brillo : _hojaOscura)
                .withValues(alpha: sol ? 0.8 : 0.45));
      canvas.restore();
    }
    final pliegue = Paint()
      ..color = _hojaOscura.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 * escala
      ..strokeCap = StrokeCap.round;
    for (final b in bolas.take(2)) {
      canvas.drawArc(b.deflate(b.width * 0.04), math.pi * 1.5, math.pi * 0.45,
          false, pliegue);
    }
    canvas.drawRect(
        Rect.fromLTRB(-2 * r, -0.3 * r, 2 * r, 0),
        Paint()
          ..color = _hojaOscura.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.2 * escala));
    canvas.restore();
    canvas.drawPath(recorte, contorno);
    // Dos cayenitas de cinco pétalos, como la flor grande.
    for (final (f, t) in [
      (Offset(-0.55 * r, -0.95 * r), 1.0),
      (Offset(0.5 * r, -1.35 * r), 0.85)
    ]) {
      final petalo = Paint()..color = _flor;
      for (var k = 0; k < 5; k++) {
        final a = -math.pi / 2 + k * 2 * math.pi / 5;
        canvas.drawCircle(f + Offset(math.cos(a), math.sin(a)) * 0.13 * r * t,
            0.12 * r * t, petalo);
      }
      canvas.drawCircle(f, 0.07 * r * t, Paint()..color = _centro);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PintorSuelo antes) => antes.avance != avance;
}

/// La cayena, la flor de Barranquilla, como la de referencia del dueño
/// (2026-10-18: «muy grande y redonda»): cinco pétalos sueltos, angostos en
/// la base y anchos arriba, con muescas entre uno y otro; contorno oscuro,
/// orla clara, la estrella oscura del centro, venas finas y brillos cortos;
/// y la columna larga que sube sobre el pétalo de arriba, con el polen
/// amarillo y los cinco estigmas rojos en la punta. Los pétalos se abren uno
/// tras otro según [avance] (0 a 1, con su rebote).
class PintorCayena extends CustomPainter {
  PintorCayena(this.avance);

  final double avance;

  /// Los granos de polen a lo largo de la columna.
  static const anteras = 14;

  /// Las cabecitas rojas de la punta.
  static const estigmas = 5;

  static const _rojo = Color(0xFFE0302A);
  static const _orla = Color(0xFFF2655B);
  static const _hondo = Color(0xFF8E1015);
  static const _trazo = Color(0xFF3D0A0A);
  static const _brillo = Color(0xFFFF8F84);
  static const _polen = Color(0xFFF6C915);
  static const _polenBorde = Color(0xFFB7860B);

  /// Un pétalo hacia arriba, con la base en el centro: angosto abajo y
  /// ancho arriba (media anchura 0,42 del radio, no 0,72 como el redondo de
  /// antes), para que entre pétalo y pétalo quede la muesca; el borde de
  /// afuera en tres ondas.
  static Path _petalo(double r) => Path()
    ..moveTo(0, 0)
    ..cubicTo(-0.14 * r, -0.08 * r, -0.44 * r, -0.34 * r, -0.42 * r, -0.62 * r)
    ..quadraticBezierTo(-0.42 * r, -0.86 * r, -0.24 * r, -0.94 * r)
    ..quadraticBezierTo(-0.12 * r, -1.02 * r, 0.02 * r, -0.97 * r)
    ..quadraticBezierTo(0.16 * r, -1.03 * r, 0.27 * r, -0.92 * r)
    ..quadraticBezierTo(0.43 * r, -0.84 * r, 0.42 * r, -0.6 * r)
    ..cubicTo(0.44 * r, -0.34 * r, 0.14 * r, -0.08 * r, 0, 0)
    ..close();

  void _unPetalo(
      Canvas canvas, Path forma, double r, Paint relleno, math.Random azar) {
    canvas.drawPath(forma, relleno);
    canvas.save();
    canvas.clipPath(forma);
    // La orla: una franja clara por dentro del borde.
    canvas.drawPath(
        forma,
        Paint()
          ..color = _orla
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.07 * r
          ..strokeJoin = StrokeJoin.round);
    // La estrella del centro: muchas rayas finas y oscuras desde la base.
    final raya = Paint()
      ..color = _hondo.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012 * r
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 16; k++) {
      final a = -0.5 + 1.0 * k / 15 + (azar.nextDouble() - 0.5) * 0.05;
      final largo = (0.3 + 0.18 * azar.nextDouble()) * r;
      canvas.drawLine(
          Offset.zero, Offset(math.sin(a) * largo, -math.cos(a) * largo), raya);
    }
    // Las venas: largas, finas y curvas, de la base casi al borde.
    final vena = Paint()
      ..color = _trazo.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.009 * r
      ..strokeCap = StrokeCap.round;
    for (final a in const [-0.62, -0.36, -0.12, 0.12, 0.36, 0.62]) {
      canvas.drawPath(
          Path()
            ..moveTo(a * 0.06 * r, -0.12 * r)
            ..quadraticBezierTo(
                a * 0.42 * r - 0.04 * r, -0.52 * r, a * 0.56 * r, -0.86 * r),
          vena);
    }
    // Brillos cortos cerca del borde, donde la hoja se dobla.
    final brillo = Paint()
      ..color = _brillo.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018 * r
      ..strokeCap = StrokeCap.round;
    for (final (x, y, l) in const [
      (-0.3, -0.62, 0.1),
      (-0.16, -0.8, 0.08),
      (0.22, -0.7, 0.1),
      (0.3, -0.5, 0.07),
    ]) {
      canvas.drawLine(
          Offset(x * r, y * r), Offset((x + l * 0.3) * r, (y - l) * r), brillo);
    }
    // La sombra donde se monta el pétalo siguiente.
    canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..cubicTo(
              0.14 * r, -0.08 * r, 0.44 * r, -0.34 * r, 0.42 * r, -0.62 * r),
        Paint()
          ..color = _hondo.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.07 * r
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.restore();
    canvas.drawPath(
        forma,
        Paint()
          ..color = _trazo
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.024 * r
          ..strokeJoin = StrokeJoin.round);
  }

  /// La columna, larga y fina, de la base a la punta, con el polen y los
  /// estigmas.
  void _columna(Canvas canvas, double r, double crece) {
    final punta = Offset(-0.04 * r, -0.7 * r * crece);
    final control = Offset(0.05 * r, -0.36 * r * crece);
    Offset sobre(double t) {
      final u = 1 - t;
      return Offset(2 * u * t * control.dx + t * t * punta.dx,
          2 * u * t * control.dy + t * t * punta.dy);
    }

    final tallo = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(control.dx, control.dy, punta.dx, punta.dy);
    for (final (color, ancho) in [
      (_trazo, 0.065 * r),
      (_rojo, 0.04 * r),
    ]) {
      canvas.drawPath(
          tallo,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = ancho
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawPath(
        tallo,
        Paint()
          ..color = _brillo
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.012 * r
          ..strokeCap = StrokeCap.round);
    // El polen: granos en sus palitos, a los dos lados del tramo de arriba.
    final palito = Paint()
      ..color = _trazo
      ..strokeWidth = 0.01 * r
      ..strokeCap = StrokeCap.round;
    final grano = Paint()..color = _polen;
    final granoBorde = Paint()
      ..color = _polenBorde
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.01 * r;
    for (var k = 0; k < anteras; k++) {
      final t = 0.55 + 0.33 * (k ~/ 2) / (anteras ~/ 2 - 1);
      final lado = k.isEven ? -1.0 : 1.0;
      final aparece = ((crece - t * 0.6) / 0.4).clamp(0.0, 1.0);
      if (aparece <= 0) continue;
      final base = sobre(t);
      final fin = base +
          Offset(lado * (0.06 + 0.03 * ((k ~/ 2).isEven ? 1 : 0)) * r,
                  -0.025 * r) *
              aparece;
      canvas.drawLine(base, fin, palito);
      final oval =
          Rect.fromCenter(center: fin, width: 0.055 * r, height: 0.045 * r);
      canvas
        ..drawOval(oval, grano)
        ..drawOval(oval, granoBorde);
    }
    // Los estigmas, al final de todo.
    final abre = ((crece - 0.8) / 0.2).clamp(0.0, 1.0);
    if (abre <= 0) return;
    for (var k = 0; k < estigmas; k++) {
      final a = -0.7 + 1.4 * k / (estigmas - 1);
      final cabeza =
          punta + Offset(math.sin(a), -math.cos(a)) * (0.08 * r * abre);
      canvas.drawLine(punta, cabeza, palito);
      canvas.drawCircle(cabeza, 0.028 * r, Paint()..color = _trazo);
      canvas.drawCircle(cabeza, 0.018 * r, Paint()..color = _rojo);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (avance <= 0) return;
    final r = size.shortestSide / 2;
    final centro = size.center(Offset.zero);
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    // La flor entera gira un poco al abrir.
    canvas.rotate(-0.35 * (1 - avance.clamp(0.0, 1.0)));
    final forma = _petalo(r);
    final relleno = Paint()
      ..shader = const RadialGradient(
        colors: [_hondo, _rojo, _rojo, _orla],
        stops: [0, 0.3, 0.8, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    for (var i = 0; i < 5; i++) {
      // Cada pétalo, con su turno: abre desde el centro y gira a su sitio.
      // Todos terminan en su tamaño (1) cuando la flor termina; solo el
      // rebote los pasa un poco.
      final desde = i * 0.09;
      final p = ((avance - desde) / (1 - desde)).clamp(0.0, 1.2);
      if (p <= 0) continue;
      canvas.save();
      canvas.rotate(i * 2 * math.pi / 5 - 0.5 * (1 - p.clamp(0.0, 1.0)));
      canvas.scale(p);
      _unPetalo(canvas, forma, r, relleno, math.Random(i));
      canvas.restore();
    }
    // La columna crece al final.
    final crece = ((avance - 0.62) / 0.38).clamp(0.0, 1.0);
    if (crece > 0) _columna(canvas, r, crece);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PintorCayena antes) => antes.avance != avance;
}
