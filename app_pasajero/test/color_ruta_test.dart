// Cada ruta con su color (dueño, 2026-10-19: «dale con las 3», el color de
// la ruta como identidad, como en Transit): la ficha, el trazo, el bus y la
// fila del selector. Los contrastes se calculan, no se miran.
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/utils/color_ruta.dart';

// `computeLuminance` es la luminancia relativa de WCAG 2.
double _contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

void main() {
  test('las nueve rutas de hoy tienen cada una su color', () {
    const codigos = [
      'B18', 'C11', 'C12', 'C13', 'C14', 'C16', 'A1', 'A3', 'A4', //
    ];
    final colores = codigos.map((c) => colorRuta('$c Nombre')).toSet();
    expect(colores, hasLength(codigos.length));
  });

  test('la letra blanca de la ficha se lee en todas: 4,5:1 o más', () {
    for (final color in coloresRuta.values) {
      expect(
          _contraste(color, const Color(0xFFFFFFFF)), greaterThanOrEqualTo(4.5),
          reason: '$color');
    }
  });

  test('y se separan del fondo del mapa (Voyager, #F2EFE9): 4:1 o más', () {
    for (final color in coloresRuta.values) {
      expect(
          _contraste(color, const Color(0xFFF2EFE9)), greaterThanOrEqualTo(4),
          reason: '$color');
    }
  });

  test('ninguna se viste de aviso: ni rojo, ni naranja, ni ámbar', () {
    // El coral es «sin conexión» y el ámbar «cuidado» (ver
    // `coloresEmpresa`): una ruta no puede decir eso.
    for (final color in coloresRuta.values) {
      final tono = HSVColor.fromColor(color).hue;
      expect(tono < 15 || tono > 60, isTrue, reason: '$color, tono $tono');
      expect(tono < 345, isTrue, reason: '$color, tono $tono');
    }
  });

  test('B18 sigue en el azul de botón de su ficha', () {
    expect(colorRuta('B18 Tcherassi'), AppColors.acento);
  });

  test('una ruta sin código, o con uno nuevo, cae al azul de botón', () {
    expect(colorRuta('Ruta Norte'), AppColors.acento);
    expect(colorRuta('Z99 Nueva'), AppColors.acento);
    expect(colorRuta(null), AppColors.acento);
    // El código se lee como en la ficha, sin importar mayúsculas.
    expect(colorRuta('c16 Calle 72'), colorRuta('C16 Calle 72'));
  });

  test('en la fila del selector el código se lee sobre su tinte: 4,5:1', () {
    // La insignia de la ruta es su tinte con el código en su color, como
    // la de la empresa pero en voz más baja.
    for (final color in coloresRuta.values) {
      expect(_contraste(color, tinteRuta(color)), greaterThanOrEqualTo(4.5),
          reason: '$color');
      expect(tinteRuta(color), isNot(const Color(0xFFFFFFFF)));
    }
  });
}
