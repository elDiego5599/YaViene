import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Luminancia relativa, tal como la define la WCAG 2.2.
///
/// El mismo cálculo que `ya_viene_core/test/contraste_test.dart`, aquí para
/// las superficies que solo existen en el pasajero (la hoja, el diálogo, la
/// bienvenida, el drawer): los tests de un paquete no pueden importar los
/// archivos de test de otro.
double luminancia(Color c) {
  double canal(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

/// Razón de contraste entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = luminancia(a);
  final lb = luminancia(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Exige el mínimo de la norma: 4,5:1 para texto normal, 3:1 para grande.
void exigeContraste(double valor, double minimo, String donde) {
  expect(
    valor,
    greaterThanOrEqualTo(minimo),
    reason: '$donde da ${valor.toStringAsFixed(2)}:1 y necesita '
        '$minimo:1.',
  );
}

/// El color con el que la letra ya quedó pintada (resuelto, no el estilo).
///
/// El color del `Text` puede venir vacío y heredarse del botón; lo que
/// pinta el motor es el del `RichText` al final.
Color letraDe(WidgetTester tester, Finder objetivo) {
  final rich = tester.widget<RichText>(
    find.descendant(of: objetivo, matching: find.byType(RichText)),
  );
  final color = rich.text.style?.color;
  expect(color, isNotNull,
      reason: 'la letra de $objetivo quedó sin color resuelto');
  return color!;
}

/// El fondo que resuelve un botón de Material en estado base (habilitado).
Color fondoDeBoton(WidgetTester tester, Finder boton) {
  final widget = tester.widget<ButtonStyleButton>(boton);
  final color = widget.style?.backgroundColor?.resolve(const <WidgetState>{});
  expect(color, isNotNull, reason: 'el botón no declara fondo');
  return color!;
}

/// El fondo del contenedor redondeado más cercano por encima del objetivo.
///
/// Para los botones pintados a mano (el CTA pegajoso de la hoja, la
/// pastilla del contador en el drawer), que no son `ButtonStyleButton`.
Color fondoDelContenedor(WidgetTester tester, Finder objetivo) {
  final contenedores = tester
      .widgetList<Container>(
        find.ancestor(of: objetivo, matching: find.byType(Container)),
      )
      .toList();
  for (final contenedor in contenedores) {
    final decoration = contenedor.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color!;
    }
  }
  fail('no hay contenedor con color por encima de $objetivo');
}
