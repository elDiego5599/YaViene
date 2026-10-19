import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../notifications/presentation/providers/distancia_aviso_provider.dart';

/// Lo que falta, dibujado: una línea de 3 km que acaba en tu punto, con el
/// bus encima deslizándose hacia ti (dueño, 2026-10-19, como la barra de
/// vuelo de Flighty). Va bajo la cifra de la hoja, en el color de la ruta
/// (`colorRuta`): de gris lo que el bus ya dejó atrás, en color lo que le
/// queda.
///
/// La escala es fija, la distancia más larga del aviso
/// ([distanciaAvisoMaxima]): el bus avanza a la misma velocidad en todas
/// las rutas, y de 3 km para allá espera al principio. Con el aviso puesto
/// lleva una marca donde va a sonar.
///
/// No se lee: la cifra de encima ya dice la distancia en voz alta.
class BarraAvance extends StatelessWidget {
  const BarraAvance({
    super.key,
    required this.metros,
    required this.color,
    this.aviso,
  });

  /// Lo que le falta al bus hasta tu punto.
  final double metros;

  /// El color de la ruta.
  final Color color;

  /// La distancia del aviso, si hay uno puesto para este bus.
  final double? aviso;

  /// Alto de la barra: lo que mide el bus, con su anillo.
  static const alto = 16.0;

  /// La pantalla más baja que la lleva. En una de 568 pt (iPhone SE de
  /// primera generación) sus 30 pt sacaban de la vista «Te avisamos a X ·
  /// Cambiar»; ahí la cifra sola dice lo mismo.
  static const pantallaMinima = 600.0;

  static const _bus = 14.0;
  static const _punto = 12.0;
  static const _grosor = 4.0;
  static const _marca = 2.0;

  /// Qué tanto del camino lleva el bus: 0 al principio (3 km o más), 1 en
  /// tu punto.
  static double avance(double metros) =>
      1 - (metros / distanciaAvisoMaxima).clamp(0.0, 1.0);

  /// Por dónde corre el bus en una barra de [ancho]: deja medio bus en
  /// cada orilla para que ni el bus ni tu punto se corten.
  static ({double izquierda, double largo}) carril(double ancho) =>
      (izquierda: _bus / 2, largo: ancho - _bus);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: alto,
        child: LayoutBuilder(builder: (context, caja) {
          final c = carril(caja.maxWidth);
          double x(double f) => c.izquierda + c.largo * f;
          Widget centrado(String key, double cx, double lado, Widget hijo) =>
              Positioned(
                key: ValueKey(key),
                left: cx - lado / 2,
                top: (alto - lado) / 2,
                width: lado,
                height: lado,
                child: hijo,
              );
          return TweenAnimationBuilder<double>(
            tween: Tween(end: avance(metros)),
            // Lo que tarda la cifra en cambiar de color: el bus y su
            // número llegan juntos.
            duration: AppMotion.duracion(context, AppMotion.pausado),
            curve: AppMotion.curvaCambio,
            builder: (context, f, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                // La línea entera, en gris: lo andado.
                Positioned(
                  left: c.izquierda,
                  width: c.largo,
                  top: (alto - _grosor) / 2,
                  height: _grosor,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.textDisabled.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(_grosor / 2),
                    ),
                  ),
                ),
                // Lo que le falta, del bus a tu punto, en su color.
                Positioned(
                  key: const ValueKey('barra-tramo'),
                  left: x(f),
                  width: c.largo * (1 - f),
                  top: (alto - _grosor) / 2,
                  height: _grosor,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(_grosor / 2),
                    ),
                  ),
                ),
                if (aviso != null)
                  centrado(
                    'barra-aviso',
                    x(avance(aviso!)),
                    10,
                    Center(
                      child: Container(
                        width: _marca,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary,
                          borderRadius: BorderRadius.circular(_marca / 2),
                        ),
                      ),
                    ),
                  ),
                // Tu punto: blanco con filo de tinta, como el centro del
                // pin.
                centrado(
                  'barra-punto',
                  x(1),
                  _punto,
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.textPrimary, width: 3),
                    ),
                  ),
                ),
                // El bus, en su color con el anillo blanco del mapa.
                centrado(
                  'barra-bus',
                  x(f),
                  _bus,
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2.5),
                      boxShadow: AppShadows.soft,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
