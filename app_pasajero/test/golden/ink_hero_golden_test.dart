@Tags(['goldens'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';

import 'golden_harness.dart';

/// La marca de la bienvenida.
///
/// Se fotografía con tinta lisa: los píxeles que importan —el logo, el
/// nombre, la bajada y sus tamaños— son todos de este widget, y su malla ya
/// la miden `fondo_malla_test` y `onboarding_hoja_test`.
void main() {
  Widget sobreTinta(Widget hijo) => ColoredBox(
        color: AppColors.ink,
        child: Center(child: hijo),
      );

  testWidgets('marca de la bienvenida', (tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(marcoGolden(sobreTinta(const InkHero())));
    await tester.pumpAndSettle();
    await coincideConOro(tester, 'ink_hero_bienvenida');
  });
}
