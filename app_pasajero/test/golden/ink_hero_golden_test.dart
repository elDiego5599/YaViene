import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';

import 'golden_harness.dart';

/// La marca sobre tinta, que es lo que se ve en el splash, en el login y en
/// la bienvenida.
///
/// Se fotografía el `InkHero` suelto y no el `SplashScreen` entero por dos
/// motivos: el splash arranca Firebase en su primer cuadro, y su fondo
/// (`LiveRouteBackdrop`) es una animación que no para nunca, así que la
/// foto saldría distinta cada vez. Los píxeles que importan —el logo, el
/// nombre, la bajada y sus tamaños— son todos de este widget.
void main() {
  Widget sobreTinta(Widget hijo) => ColoredBox(
        color: AppColors.ink,
        child: Center(child: hijo),
      );

  testWidgets('marca del splash (84/34/15)', (tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(
      marcoGolden(
        sobreTinta(
          const InkHero(
            logoSize: 84,
            titleFontSize: 34,
            taglineFontSize: 15,
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
    );
    // Nada de `pumpAndSettle` aquí: el indicador de carga gira para
    // siempre y la espera nunca terminaria. Se avanza un tiempo fijo, que
    // deja el spinner en la misma fase en cada corrida.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await coincideConOro(tester, 'ink_hero_splash');
  });

  testWidgets('marca del login (88/36/16)', (tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(marcoGolden(sobreTinta(const InkHero())));
    await tester.pumpAndSettle();
    await coincideConOro(tester, 'ink_hero_login');
  });
}
