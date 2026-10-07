import 'package:flutter/cupertino.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/utils/distancia.dart';
import '../../../notifications/presentation/providers/distancia_aviso_provider.dart';

/// La franja que marca la distancia elegida: el verde de la marca al 10 %,
/// en lugar del gris del sistema, para que la rueda sea de la app y no un
/// control prestado. Con la cifra en `textPrimary` encima da 16:1.
final Color franjaRuedaDistancia = AppColors.primary.withValues(alpha: 0.10);

int _indiceDe(int metros) =>
    ((metros.clamp(distanciaAvisoMinima, distanciaAvisoMaxima) -
                distanciaAvisoMinima) /
            pasoDistanciaAviso)
        .round();

/// La distancia en la que arranca la rueda para [metros]: la misma si la
/// ofrece y, si no, la más cercana que sí. Es la que vale si se guarda sin
/// girarla.
int distanciaEnRueda(int metros) => distanciasDeAviso[_indiceDe(metros)];

/// La rueda de la distancia del aviso, como la de la alarma del iPhone
/// (dueño, 2026-10-06): de 500 m a 3 km en pasos de 100 m.
class RuedaDistancia extends StatefulWidget {
  const RuedaDistancia({
    super.key,
    required this.inicial,
    required this.alCambiar,
  });

  /// Dónde arranca. Una distancia que la rueda no ofrece arranca en la más
  /// cercana que sí.
  final int inicial;
  final ValueChanged<int> alCambiar;

  @override
  State<RuedaDistancia> createState() => _RuedaDistanciaState();
}

class _RuedaDistanciaState extends State<RuedaDistancia> {
  late final FixedExtentScrollController _control =
      FixedExtentScrollController(initialItem: _indiceDe(widget.inicial));

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
    // Cinco filas a la vista, la elegida en medio. Se queda en tres con el
    // texto grande o en un teléfono de menos de 640 de alto (el SE de
    // 568): la tarjeta con cinco mide unos 600 y no dejaría ver los
    // botones. La de arriba y la de abajo bastan para saber hacia dónde se
    // gira.
    final filas =
        escala.scale(1) > 1.3 || MediaQuery.sizeOf(context).height < 640
            ? 3
            : 5;
    return Semantics(
      container: true,
      label: 'Distancia del aviso',
      child: SizedBox(
        height: fila * filas,
        child: CupertinoPicker(
          scrollController: _control,
          itemExtent: fila,
          useMagnifier: true,
          magnification: 1.08,
          selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
            background: franjaRuedaDistancia,
          ),
          onSelectedItemChanged: (i) => widget.alCambiar(distanciasDeAviso[i]),
          children: [
            for (final m in distanciasDeAviso)
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
