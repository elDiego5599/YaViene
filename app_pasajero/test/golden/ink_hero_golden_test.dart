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
/// La bienvenida se fotografía con tinta lisa y no con su fondo
/// (`LiveRouteBackdrop`), que es una animación que no para nunca: la foto
/// saldría distinta cada vez. Los píxeles que importan —el logo, el nombre,
/// la bajada y sus tamaños— son todos de este widget. La malla del splash
/// sí va: es quieta.
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
    // siempre y la espera nunca terminaria. Se avanza un tiempo fijo, que
    // deja el spinner en la misma fase en cada corrida.
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
