import 'package:maplibre_gl/maplibre_gl.dart';

/// Cómo se pinta la ruta elegida en el mapa: línea, orla y paradas.
///
/// Es la misma ruta que enseña «El producto» en la web
/// (`YaVieneWeb/src/css/componentes/mapa.css`, `.mv-casing` y
/// `.mv-activa`): el verde de la marca sobre una orla blanca. Aquí iba en
/// el azul eléctrico (#2563EB), sola, y la web la dibujaba en verde; el
/// dueño pidió una sola, la del producto (2026-09-28). El mockup del
/// teléfono en la web espeja estos números (`phone-simulator.css`).
///
/// Vive aparte de `map_widget.dart` para que `test/estilo_ruta_test.dart`
/// pueda leer lo que recibe MapLibre sin levantar un mapa.
abstract final class EstiloRuta {
  /// El verde de la marca (`AppColors.primary`), en el texto que pide
  /// MapLibre.
  static const String _verde = '#00A859';

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

  /// La línea, entera: en la web el verde no lleva transparencia, y con la
  /// orla debajo tampoco le hace falta para no tapar las calles.
  static const LineLayerProperties linea = LineLayerProperties(
    lineColor: _verde,
    lineWidth: 4.0,
    lineOpacity: 1.0,
    lineCap: 'round',
    lineJoin: 'round',
  );

  /// Parada fija: blanca con filo verde, como los terminales del producto.
  static const CircleLayerProperties paradaFija = CircleLayerProperties(
    circleRadius: 7.0,
    circleColor: '#FFFFFF',
    circleStrokeWidth: 2.5,
    circleStrokeColor: _verde,
  );

  /// Parada informal: la zona tenue donde el bus suele parar, en el mismo
  /// verde de la ruta a la que pertenece.
  static const CircleLayerProperties paradaInformal = CircleLayerProperties(
    circleRadius: 30.0,
    circleColor: _verde,
    circleOpacity: 0.12,
    circleStrokeWidth: 1.5,
    circleStrokeColor: _verde,
    circleStrokeOpacity: 0.3,
  );
}
