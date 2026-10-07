import 'package:flutter/cupertino.dart';
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

int _indiceDe(int metros, int? hasta) =>
    ((metros.clamp(distanciaAvisoMinima, hasta ?? distanciaAvisoMaxima) -
                distanciaAvisoMinima) /
            pasoDistanciaAviso)
        .round();

/// La distancia en la que arranca la rueda para [metros]: la misma si la
/// ofrece y, si no, la más cercana que sí. Es la que vale si se guarda sin
/// girarla.
int distanciaEnRueda(int metros, {int? hasta}) =>
    distanciasDeAviso[_indiceDe(metros, hasta)];

/// La rueda de la distancia del aviso, como la de la alarma del iPhone
/// (dueño, 2026-10-06): de 500 m a 3 km en pasos de 100 m.
class RuedaDistancia extends StatefulWidget {
  const RuedaDistancia({
    super.key,
    required this.inicial,
    required this.alCambiar,
    this.hasta,
  });

  /// Dónde arranca. Una distancia que la rueda no ofrece arranca en la más
  /// cercana que sí.
  final int inicial;

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
      initialItem: _indiceDe(widget.inicial, widget.hasta));

  List<int> get _opciones => [
        for (final m in distanciasDeAviso)
          if (m <= (widget.hasta ?? distanciaAvisoMaxima)) m,
      ];

  @override
  void didUpdateWidget(RuedaDistancia antes) {
    super.didUpdateWidget(antes);
    final ultima = _opciones.length - 1;
    if (widget.hasta == antes.hasta || _control.selectedItem <= ultima) {
      return;
    }
    // Las filas que sobran se van por abajo: las de arriba no cambian de
    // índice y solo hay que mover la rueda si la elegida era de las que se
    // fueron. Tras el cuadro, con la lista nueva ya puesta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _control.jumpToItem(ultima);
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
        child: CupertinoPicker(
          scrollController: _control,
          itemExtent: fila,
          squeeze: _apriete,
          useMagnifier: true,
          magnification: 1.08,
          selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
            background: franjaRuedaDistancia,
          ),
          onSelectedItemChanged: (i) => widget.alCambiar(_opciones[i]),
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
    );
  }
}
