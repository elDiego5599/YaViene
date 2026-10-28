// Cada empresa con su color, el de su insignia en «Elige empresa», que
// también viste la ficha del aviso (dueño, 2026-10-19). Los contrastes se
// calculan, no se miran.
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/utils/color_empresa.dart';

double _contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

void main() {
  test('la misma empresa sale siempre del mismo color', () {
    expect(colorEmpresa('EMP-01'), colorEmpresa('EMP-01'));
    expect(coloresEmpresa, contains(colorEmpresa('EMP-03')));
  });

  test('las empresas de hoy no se confunden entre sí', () {
    final colores = ['EMP-01', 'EMP-03', 'EMP-04'].map(colorEmpresa).toSet();
    expect(colores, hasLength(3));
  });

  test('Coochofal va en su rojito, con letra blanca legible', () {
    // El dueño lo pidió rojito (2026-10-28).
    expect(colorEmpresa('EMP-04'), rojoCoochofal);
    expect(_contraste(rojoCoochofal, const Color(0xFFFFFFFF)),
        greaterThanOrEqualTo(4.5));
    // No es el coral del bus en el mapa: una ficha no se confunde con él.
    expect(rojoCoochofal, isNot(AppColors.busActive));
  });

  test('la letra blanca de la insignia y la ficha se lee: 4,5:1 o más', () {
    for (final color in coloresEmpresa) {
      expect(
          _contraste(color, const Color(0xFFFFFFFF)), greaterThanOrEqualTo(4.5),
          reason: '$color');
    }
  });

  test('la ficha del aviso va en el color de su empresa', () {
    expect(colorFicha(companyId: 'EMP-01'), colorEmpresa('EMP-01'));
    // Un aviso de antes no sabe su empresa: queda en el azul de siempre.
    expect(colorFicha(), AppColors.acento);
  });
}
