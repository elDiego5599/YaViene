import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/utils/distancia.dart';
import '../../../notifications/presentation/providers/distancia_aviso_provider.dart';

/// La franja que marca la distancia elegida: el verde de la marca al 10 %,
/// en lugar del gris del sistema, para que la rueda sea de la app y no un
/// control prestado. Con la cifra en `textPrimary` encima da 16:1.
final Color franjaRuedaDistancia = AppColors.primary.withValues(alpha: 0.10);

/// El `squeeze` del picker de iOS (1,45, privado en Flutter): lo junto que
/// van las filas en el cilindro.
const double _apriete = 1.45;

/// Las que ofrece la rueda entre [desde] y [hasta]. Nunca vacía: si el bus
/// ya pasó lo más cerca que llega la ruta, queda solo [desde], y quien la
/// abre ya lo había rechazado.
List<int> _opcionesDe(int? desde, int? hasta) {
  final piso = (desde ?? distanciaAvisoMinima)
      .clamp(distanciaAvisoMinima, distanciaAvisoMaxima);
  final techo =
      (hasta ?? distanciaAvisoMaxima).clamp(piso, distanciaAvisoMaxima);
  return [
    for (final m in distanciasDeAviso)
      if (m >= piso && m <= techo) m,
  ];
}

int _indiceDe(int metros, List<int> opciones) =>
    ((metros.clamp(opciones.first, opciones.last) - opciones.first) /
            pasoDistanciaAviso)
        .round();

/// La distancia en la que arranca la rueda para [metros]: la misma si la
/// ofrece y, si no, la más cercana que sí. Es la que vale si se guarda sin
/// girarla.
int distanciaEnRueda(int metros, {int? desde, int? hasta}) {
  final opciones = _opcionesDe(desde, hasta);
  return opciones[_indiceDe(metros, opciones)];
}

/// La rueda de la distancia del aviso, como la de la alarma del iPhone
/// (dueño, 2026-10-06): de 500 m a 3 km en pasos de 100 m.
class RuedaDistancia extends StatefulWidget {
  const RuedaDistancia({
    super.key,
    required this.inicial,
    required this.alCambiar,
    this.desde,
    this.hasta,
  });

  /// Dónde arranca. Una distancia que la rueda no ofrece arranca en la más
  /// cercana que sí.
  final int inicial;

  /// La menor que ofrece: lo más cerca que pasa la ruta, porque una menor no
  /// sonaría nunca (dueño, 2026-10-07). `null`, desde 500 m.
  final int? desde;

  /// La mayor que ofrece: la que el bus todavía no ha pasado (dueño,
  /// 2026-10-07). `null`, hasta 3 km. Puede cambiar con la rueda abierta,
  /// porque el bus se mueve: si baja de la elegida, la rueda va a ella.
  final int? hasta;
  final ValueChanged<int> alCambiar;

  @override
  State<RuedaDistancia> createState() => _RuedaDistanciaState();
}

class _RuedaDistanciaState extends State<RuedaDistancia> {
  late final FixedExtentScrollController _control = FixedExtentScrollController(
      initialItem: _indiceDe(widget.inicial, _opciones));

  List<int> get _opciones => _opcionesDe(widget.desde, widget.hasta);

  @override
  void didUpdateWidget(RuedaDistancia antes) {
    super.didUpdateWidget(antes);
    if (widget.desde == antes.desde && widget.hasta == antes.hasta) return;
    final viejas = _opcionesDe(antes.desde, antes.hasta);
    final elegida = viejas[_control.selectedItem.clamp(0, viejas.length - 1)];
    final indice = _indiceDe(elegida, _opciones);
    if (indice == _control.selectedItem) return;
    // Las filas que sobran se van por abajo: las de arriba no cambian de
    // índice y solo hay que mover la rueda si la elegida era de las que se
    // fueron. Tras el cuadro, con la lista nueva ya puesta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _control.jumpToItem(indice);
    });
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context);
    // 40 por fila con el texto normal: la cifra de 22 cabe con aire, como
    // en la alarma del iPhone. Crece con el texto (30 de los 40) para que
    // la cifra no se corte, y los 10 de aire se quedan fijos: al doble, 70
    // y no 80, que es lo que deja caber la tarjeta entera con sus botones
    // en un iPhone 13.
    final fila = 10 + escala.scale(30);
    // Cinco filas a la vista, la elegida en medio: dos arriba y dos abajo,
    // sin media fila más asomando en los bordes (dueño, 2026-10-06). Se
    // queda en tres con el texto grande o en un teléfono de menos de 640 de
    // alto (el SE de 568): la tarjeta con cinco no dejaría ver los botones.
    // La de arriba y la de abajo bastan para saber hacia dónde se gira.
    final filas =
        escala.scale(1) > 1.3 || MediaQuery.sizeOf(context).height < 640
            ? 3
            : 5;
    return Semantics(
      container: true,
      label: 'Distancia del aviso',
      child: SizedBox(
        // El picker pinta las filas que caben en su alto por `squeeze`: con
        // `fila * filas` de alto pintaba siete, las dos de los bordes
        // aplastadas. Dividido por él caben justo [filas], y la rueda queda
        // más baja.
        height: fila * filas / _apriete,
        // Las filas de los bordes se apagan hacia fuera, como en la rueda
        // del iPhone, en vez de cortarse en seco contra la tarjeta
        // (AUD29-36). El desvanecido ocupa el alto de una fila de las
        // que se ven (fila / alto = apriete / filas) y arranca en el 15 %,
        // no en cero, para que la del borde se lea todavía.
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (caja) {
            final borde = _apriete / filas;
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Color(0x26000000),
                Color(0xFF000000),
                Color(0xFF000000),
                Color(0x26000000),
              ],
              stops: [0, borde, 1 - borde, 1],
            ).createShader(caja);
          },
          child: CupertinoPicker(
            scrollController: _control,
            itemExtent: fila,
            squeeze: _apriete,
            useMagnifier: true,
            magnification: 1.08,
            selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
              background: franjaRuedaDistancia,
            ),
            // Cada paso se siente en el dedo, como en la alarma del iPhone. En
            // iOS el picker ya lo da; en Android no daba nada.
            onSelectedItemChanged: (i) {
              if (defaultTargetPlatform != TargetPlatform.iOS) {
                HapticFeedback.selectionClick();
              }
              widget.alCambiar(_opciones[i]);
            },
            children: [
              for (final m in _opciones)
                Center(
                  child: Semantics(
                    label: distanciaAvisoHablada(m),
                    excludeSemantics: true,
                    child: Text(
                      distanciaAviso(m),
                      // Cifras de ancho fijo: al girar, «1,1 km» y «1,8 km»
                      // ocupan lo mismo y la columna no baila.
                      style: AppTextStyles.titulo.copyWith(
                        color: AppColors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
