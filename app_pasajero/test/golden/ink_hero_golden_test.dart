@Tags(['goldens'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/fondo_texturizado.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';

import 'golden_harness.dart';

/// La marca de la bienvenida.
///
/// Sobre el blanco texturizado de la bienvenida, como en la pantalla: el
/// contraste de la letra sobre él lo mide `onboarding_hoja_test`.
void main() {
  Widget sobreTextura(Widget hijo) => Stack(
        children: [
          const Positioned.fill(child: FondoTexturizado()),
          Center(child: hijo)
        ],
      );

  testWidgets('marca de la bienvenida', (tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(marcoGolden(sobreTextura(const InkHero())));
    await tester.pumpAndSettle();
    await coincideConOro(tester, 'ink_hero_bienvenida');
  });
}
