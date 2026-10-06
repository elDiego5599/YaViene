import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/utils/distancia.dart';
import '../../../../core/widgets/dialogo.dart';
import '../../../notifications/presentation/providers/distancia_aviso_provider.dart';

/// La franja que marca la distancia elegida: el verde de la marca al 10 %,
/// en lugar del gris del sistema, para que la rueda sea de la app y no un
/// control prestado. Con la cifra en `textPrimary` encima da 16:1.
final Color franjaRuedaDistancia = AppColors.primary.withValues(alpha: 0.10);

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

  static int _indiceDe(int metros) =>
      ((metros.clamp(distanciaAvisoMinima, distanciaAvisoMaxima) -
                  distanciaAvisoMinima) /
              pasoDistanciaAviso)
          .round();

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context);
    // 40 por fila con el texto normal: la cifra de 22 cabe con aire, como
    // en la alarma del iPhone. La fila crece con el texto para que la
    // cifra no se corte.
    final fila = escala.scale(40);
    // Cinco filas a la vista, la elegida en medio. Con el texto grande la
    // rueda se queda en tres: cinco de 80 no dejarían ver los botones en un
    // teléfono pequeño, y la de arriba y la de abajo bastan para saber
    // hacia dónde se gira.
    final filas = escala.scale(1) > 1.3 ? 3 : 5;
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

/// Pregunta a qué distancia avisar. [primeraVez]: al activar el primer
/// aviso, con «Guardar» y «Solo esta vez». Si no, es «Cambiar», con
/// «Guardar» y «Cancelar»; [avisoActivo] dice que el cambio también toca el
/// aviso que suena por este bus. Tocar fuera o «Cancelar» devuelve `null`.
Future<({int metros, bool guardar})?> elegirDistanciaAviso(
  BuildContext context, {
  int inicial = distanciaAvisoInicial,
  bool primeraVez = true,
  bool avisoActivo = false,
}) {
  var metros = distanciasDeAviso[_RuedaDistanciaState._indiceDe(inicial)];
  return mostrarDialogo<({int metros, bool guardar})>(
    context,
    (ventana) => Dialogo(
      icono: Icons.notifications_active_outlined,
      titulo:
          primeraVez ? '¿A qué distancia te avisamos?' : 'Distancia del aviso',
      mensaje: primeraVez
          ? 'Te avisamos cuando el bus esté así de cerca. Guárdala y no te '
              'lo volvemos a preguntar; la cambias cuando quieras.'
          : avisoActivo
              ? 'Te avisamos cuando el bus esté así de cerca. También cambia '
                  'el aviso que tienes activo.'
              : 'Te avisamos cuando el bus esté así de cerca.',
      contenido: RuedaDistancia(
        inicial: metros,
        alCambiar: (m) => metros = m,
      ),
      principal: DialogoAccion(
        'Guardar',
        () => Navigator.pop(ventana, (metros: metros, guardar: true)),
      ),
      secundaria: primeraVez
          ? DialogoAccion(
              'Solo esta vez',
              () => Navigator.pop(ventana, (metros: metros, guardar: false)),
            )
          : DialogoAccion('Cancelar', () => Navigator.pop(ventana)),
    ),
  );
}
