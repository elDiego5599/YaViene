import 'package:flutter/painting.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/utils/color_ruta.dart';

/// Cómo se pinta la ruta elegida en el mapa: línea, orla y paradas.
///
/// La línea sobre una orla blanca (dueño, 2026-09-28), con la línea y las
/// paradas en el color de su ruta (`colorRuta`, dueño, 2026-10-19), el
/// mismo de su ficha y de su bus. El teléfono de la web espeja estos
/// números (`YaVieneWeb/src/css/phone-simulator.css`, `color-ruta.ts`).
///
/// Vive aparte de `map_widget.dart` para que `test/estilo_ruta_test.dart`
/// pueda leer lo que recibe MapLibre sin levantar un mapa.
abstract final class EstiloRuta {
  /// La orla, debajo de la línea. En la web mide 7 contra 3,4 de línea;
  /// aquí la línea se queda en los 4 que ya medía y la orla guarda esa
  /// proporción (≈ 2×). Separa la ruta de las calles de Voyager, que son
  /// de su mismo calibre.
  static const LineLayerProperties orla = LineLayerProperties(
    lineColor: '#FFFFFF',
    lineWidth: 8.0,
    lineOpacity: 0.95,
    lineCap: 'round',
    lineJoin: 'round',
  );

  /// La línea, entera: en la web no lleva transparencia, y con la orla
  /// debajo tampoco le hace falta para no tapar las calles.
  static LineLayerProperties linea(Color color) => LineLayerProperties(
        lineColor: hexDe(color),
        lineWidth: 4.0,
        lineOpacity: 1.0,
        lineCap: 'round',
        lineJoin: 'round',
      );

  /// Parada fija: blanca con filo del color de la ruta, como los
  /// terminales del producto.
  static CircleLayerProperties paradaFija(Color color) => CircleLayerProperties(
        circleRadius: 7.0,
        circleColor: '#FFFFFF',
        circleStrokeWidth: 2.5,
        circleStrokeColor: hexDe(color),
      );

  /// Parada informal: la zona tenue donde el bus suele parar, en el color
  /// de la ruta a la que pertenece.
  static CircleLayerProperties paradaInformal(Color color) =>
      CircleLayerProperties(
        circleRadius: 30.0,
        circleColor: hexDe(color),
        circleOpacity: 0.12,
        circleStrokeWidth: 1.5,
        circleStrokeColor: hexDe(color),
        circleStrokeOpacity: 0.3,
      );
}
