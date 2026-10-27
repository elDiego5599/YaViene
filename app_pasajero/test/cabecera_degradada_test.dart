import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/cabecera_degradada.dart';
import 'package:ya_viene_pasajero/core/widgets/fondo_texturizado.dart';

double _contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  // El título de la barra va en tinta sobre todo el degradado: se mide
  // contra el tono más oscuro, sin contar el brillo, que solo aclara.
  test('el título se lee AAA en toda la cabecera', () {
    final colores =
        (CabeceraDegradada.decoracion.gradient! as LinearGradient).colors;
    for (final c in colores) {
      expect(_contraste(AppColors.textPrimary, c), greaterThanOrEqualTo(7));
    }
    expect(_contraste(AppColors.textPrimary, CabeceraDegradada.azul),
        closeTo(14.0, 0.1));
  });

  // «El texturizado en Avisos e Info quítaselo a la parte de color y ponlo
  // en la parte blanca» (dueño, 2026-10-27): el degradado va liso.
  testWidgets('la cabecera va sin grano', (tester) async {
    await tester.pumpWidget(const CabeceraDegradada());
    expect(find.byType(Grano), findsNothing);
  });
}
