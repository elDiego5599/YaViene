// La ruta pintada en el mapa: su color sobre la orla blanca del producto.
//
// La web la enseña con una orla blanca debajo (`YaVieneWeb/src/css/
// componentes/mapa.css`, `.mv-casing` y `.mv-activa`), y el dueño pidió una
// sola, la del producto (2026-09-28). Desde el 2026-10-19 la línea va en el
// color de su ruta (`colorRuta`), como la ficha y el bus. Aquí se ata lo que
// MapLibre recibe, capa por capa.
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/utils/color_ruta.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/estilo_ruta.dart';

void main() {
  const indigo = Color(0xFF4338CA);

  test('el color va en el #RRGGBB que pide MapLibre', () {
    expect(hexDe(indigo), '#4338CA');
    expect(hexDe(const Color(0xFF047857)), '#047857');
    // La transparencia no entra: MapLibre la lleva aparte.
    expect(hexDe(const Color(0x80047857)), '#047857');
  });

  test('la ruta va en su color, entera', () {
    expect(EstiloRuta.linea(indigo).lineColor, '#4338CA');
    expect(EstiloRuta.linea(indigo).lineOpacity, 1.0);
  });

  test('con la orla blanca del producto debajo, del doble de ancho', () {
    expect(EstiloRuta.orla.lineColor, '#FFFFFF');
    expect(EstiloRuta.orla.lineOpacity, 0.95);
    // En la web: 7 de orla contra 3,4 de línea. Aquí la línea mide 4 (lo
    // que ya medía la azul) y la orla guarda la misma proporción.
    final linea = EstiloRuta.linea(indigo).lineWidth as double;
    final orla = EstiloRuta.orla.lineWidth as double;
    expect(orla / linea, closeTo(7 / 3.4, 0.1));
    expect(EstiloRuta.orla.lineCap, EstiloRuta.linea(indigo).lineCap);
    expect(EstiloRuta.orla.lineJoin, EstiloRuta.linea(indigo).lineJoin);
  });

  test('las paradas van en el color de su ruta', () {
    expect(EstiloRuta.paradaFija(indigo).circleColor, '#FFFFFF');
    expect(EstiloRuta.paradaFija(indigo).circleStrokeColor, '#4338CA');
    expect(EstiloRuta.paradaInformal(indigo).circleColor, '#4338CA');
    expect(EstiloRuta.paradaInformal(indigo).circleStrokeColor, '#4338CA');
  });
}
