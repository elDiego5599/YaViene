import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Un número que cambia como los de iOS: solo giran las cifras que
/// cambian, cada una con un leve desenfoque en la dirección en que se
/// mueve. Lo usa la distancia de la hoja del bus, que cambia con cada
/// posición que llega; en seco, «850» → «849» parece un parpadeo y no algo
/// que se acerca.
///
/// En reposo es un `Text` normal —mismo árbol, misma voz, mismas
/// pruebas—; solo mientras gira se parte en cifras. Las cifras son
/// tabulares (todas del mismo ancho): así el número no tiembla de ancho al
/// cambiar, y las cifras sueltas del giro miden lo mismo que el texto
/// entero. Sin interletraje por pares, por lo mismo.
///
/// Gira solo de número a número. De una palabra («Calculando») a un número
/// no hay cifras que casar, y cambia en seco, como antes. Con el movimiento
/// reducido del sistema, también en seco.
class CifraViva extends StatefulWidget {
  const CifraViva(
    this.texto, {
    super.key,
    required this.style,
    this.valor,
  });

  final String texto;
  final TextStyle style;

  /// El valor que el texto representa, para saber hacia dónde girar: si
  /// baja, lo nuevo entra desde arriba; si sube, desde abajo. Es lo que
  /// hace iOS con sus cuentas atrás. Sin él, siempre desde abajo.
  final double? valor;

  /// Lo que dura un giro. El de un elemento que cambia de sitio
  /// (`AppMotion.pausado`): el número es lo más grande de la hoja y un giro
  /// más corto se lee como un tirón.
  static const duracion = AppMotion.pausado;

  /// Cuánto se desplaza la cifra que entra o sale, en altos de letra.
  /// Menos de media letra: el giro se insinúa y la cifra no llega a salir
  /// de su renglón.
  static const recorrido = 0.42;

  /// El desenfoque máximo, en puntos, a mitad de giro. Solo vertical: es
  /// la estela del movimiento, no una niebla.
  static const desenfoque = 5.0;

  static final RegExp _numerico = RegExp(r'^[0-9.,]+$');

  @override
  State<CifraViva> createState() => _CifraVivaState();
}

class _CifraVivaState extends State<CifraViva>
    with SingleTickerProviderStateMixin {
  // En `initState` y no perezoso: un `late` sin usar se crearía por
  // primera vez en `dispose`, con el árbol ya desmontado.
  late final AnimationController _giro;

  /// El texto del que se viene mientras se gira; `null` en reposo.
  String? _desde;
  bool _baja = false;

  @override
  void initState() {
    super.initState();
    _giro = AnimationController(vsync: this, duration: CifraViva.duracion)
      ..addStatusListener((estado) {
        if (estado == AnimationStatus.completed) {
          setState(() => _desde = null);
        }
      });
  }

  @override
  void didUpdateWidget(covariant CifraViva viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.texto == widget.texto) return;
    final girable = !AppMotion.reducido(context) &&
        CifraViva._numerico.hasMatch(viejo.texto) &&
        CifraViva._numerico.hasMatch(widget.texto);
    if (!girable) {
      _giro.stop();
      _desde = null;
      return;
    }
    // Un giro cortado por otro arranca desde lo último que se pidió, no
    // desde lo que había a medias: la cifra que se veía es la de antes.
    _desde = viejo.texto;
    final antes = viejo.valor, ahora = widget.valor;
    _baja = antes != null && ahora != null && ahora < antes;
    _giro.forward(from: 0);
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  TextStyle get _estilo => widget.style.copyWith(
        fontFeatures: const [
          FontFeature.tabularFigures(),
          FontFeature.disable('kern'),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final estilo = _estilo;
    final desde = _desde;
    if (desde == null) return Text(widget.texto, style: estilo);

    // Las cifras se casan por la derecha: las unidades con las unidades.
    // Si uno es más largo, al otro le faltan cifras a la izquierda, que
    // entran o salen desde la nada.
    final largo = math.max(desde.length, widget.texto.length);
    final viejo = desde.padLeft(largo, ' ');
    final nuevo = widget.texto.padLeft(largo, ' ');
    return AnimatedBuilder(
      animation: _giro,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < largo; i++)
              if (viejo[i] == nuevo[i])
                Text(nuevo[i], style: estilo)
              else
                _Giro(
                  sale: viejo[i],
                  entra: nuevo[i],
                  t: _giro.value,
                  baja: _baja,
                  estilo: estilo,
                ),
          ],
        );
      },
    );
  }
}

/// Una cifra a medio giro: la que sale y la que entra, una encima de otra.
class _Giro extends StatelessWidget {
  const _Giro({
    required this.sale,
    required this.entra,
    required this.t,
    required this.baja,
    required this.estilo,
  });

  final String sale;
  final String entra;
  final double t;
  final bool baja;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) {
    final alto = (estilo.fontSize ?? 14) * (estilo.height ?? 1);
    // Baja: lo nuevo viene de arriba (dy negativo) y lo viejo se va abajo.
    final signo = baja ? -1.0 : 1.0;
    final llegada = AppMotion.curvaEntrada.transform(t);
    final ida = AppMotion.curvaSalida.transform(t);
    return Stack(
      alignment: Alignment.center,
      children: [
        if (sale.trim().isNotEmpty)
          _cifra(sale, -signo * CifraViva.recorrido * alto * ida, 1 - ida,
              math.sin(math.pi * math.min(ida, 1) / 2)),
        if (entra.trim().isNotEmpty)
          _cifra(
            entra,
            signo * CifraViva.recorrido * alto * (1 - llegada),
            llegada,
            1 - llegada,
          ),
      ],
    );
  }

  Widget _cifra(String cifra, double dy, double opacidad, double borroso) {
    final sigma = CifraViva.desenfoque * borroso.clamp(0.0, 1.0);
    Widget hijo = Text(cifra, style: estilo);
    if (sigma > 0.05) {
      hijo = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaY: sigma),
        child: hijo,
      );
    }
    return Transform.translate(
      offset: Offset(0, dy),
      child: Opacity(opacity: opacidad.clamp(0.0, 1.0), child: hijo),
    );
  }
}
