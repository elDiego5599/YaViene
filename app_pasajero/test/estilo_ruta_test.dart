// La ruta pintada en el mapa, del mismo color que en «El producto» de la web.
//
// El mapa del pasajero pintaba la ruta en el azul eléctrico (#2563EB), sola,
// y la web la enseña en el verde de la marca con una orla blanca debajo
// (`YaVieneWeb/src/css/componentes/mapa.css`, `.mv-casing` y `.mv-activa`).
// El dueño pidió una sola: la del producto (2026-09-28). Aquí se ata lo que
// MapLibre recibe, capa por capa.
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/estilo_ruta.dart';

void main() {
  const verde = '#00A859';

  test('la ruta va en el verde de la marca, entera', () {
    expect(EstiloRuta.linea.lineColor, verde);
    expect(EstiloRuta.linea.lineOpacity, 1.0);
  });

  test('con la orla blanca del producto debajo, del doble de ancho', () {
    expect(EstiloRuta.orla.lineColor, '#FFFFFF');
    expect(EstiloRuta.orla.lineOpacity, 0.95);
    // En la web: 7 de orla contra 3,4 de línea. Aquí la línea mide 4 (lo
    // que ya medía la azul) y la orla guarda la misma proporción.
    final linea = EstiloRuta.linea.lineWidth as double;
    final orla = EstiloRuta.orla.lineWidth as double;
    expect(orla / linea, closeTo(7 / 3.4, 0.1));
    expect(EstiloRuta.orla.lineCap, EstiloRuta.linea.lineCap);
    expect(EstiloRuta.orla.lineJoin, EstiloRuta.linea.lineJoin);
  });

  test('las paradas van en el mismo verde: ni un azul queda en la ruta', () {
    expect(EstiloRuta.paradaFija.circleColor, '#FFFFFF');
    expect(EstiloRuta.paradaFija.circleStrokeColor, verde);
    expect(EstiloRuta.paradaInformal.circleColor, verde);
    expect(EstiloRuta.paradaInformal.circleStrokeColor, verde);
  });
}
