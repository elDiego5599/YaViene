@Tags(['goldens'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/fondo_malla.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';

import 'golden_harness.dart';

/// La marca sobre la malla del splash y sobre la tinta de la bienvenida.
///
/// La bienvenida se fotografía con tinta lisa: los píxeles que importan
/// —el logo, el nombre, la bajada y sus tamaños— son todos de este widget,
/// y su malla ya la miden `fondo_malla_test` y `onboarding_hoja_test`. La
/// del splash sí va: respira, pero a un tiempo fijo sale siempre igual.
void main() {
  Widget sobreTinta(Widget hijo) => ColoredBox(
        color: AppColors.ink,
        child: Center(child: hijo),
      );

  testWidgets('marca del splash: logo de 84, el del arranque nativo',
      (tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(
      marcoGolden(
        const FondoMalla(
          child: Center(
            child: InkHero(
              logoSize: 84,
              spacingAfterLogo: 20,
              trailing: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color.fromRGBO(255, 255, 255, 0.6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Nada de `pumpAndSettle` aquí: el indicador de carga gira para
    // siempre —y la malla respira— y la espera nunca terminaría. Se avanza
    // un tiempo fijo, que deja los dos en la misma fase en cada corrida.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await coincideConOro(tester, 'ink_hero_splash');
  });

  testWidgets('marca de la bienvenida', (tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(marcoGolden(sobreTinta(const InkHero())));
    await tester.pumpAndSettle();
    await coincideConOro(tester, 'ink_hero_bienvenida');
  });
}
