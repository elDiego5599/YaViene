@Tags(['goldens'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/widgets/'
    'fondo_matizado.dart';

import 'golden_harness.dart';

/// La marca de la bienvenida.
///
/// Sobre el matizado del arranque, como en la pantalla: el contraste de la
/// letra sobre él lo mide `onboarding_hoja_test`.
void main() {
  Widget sobreMatizado(Widget hijo) => CustomPaint(
        painter: const PintorMatizado(),
        child: Center(child: hijo),
      );

  testWidgets('marca de la bienvenida', (tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(marcoGolden(sobreMatizado(const InkHero())));
    await tester.pumpAndSettle();
    await coincideConOro(tester, 'ink_hero_bienvenida');
  });
}
