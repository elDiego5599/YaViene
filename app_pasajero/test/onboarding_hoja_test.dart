import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/onboarding/presentation/screens/'
    'onboarding_screen.dart';

import 'golden/golden_harness.dart';

/// La hoja de la bienvenida: pocas palabras y grandes.
///
/// El dueño (2026-09-27): «hay mucho texto y hace que todos se vean
/// pequeños». La hoja decía lo mismo tres veces —un subtítulo y una letra
/// chica por cada razón— y para que cupiera todo, todo iba a 12 y 15. Se
/// quedó lo necesario: el título, tres razones de una línea, el sí legal y
/// los dos botones. Estas pruebas fijan que no vuelva lo que se fue y que
/// lo que se quedó conserve su tamaño.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> abrir(WidgetTester tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(
      ProviderScope(child: marcoGoldenRuteado(const OnboardingScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  double tamano(WidgetTester tester, String texto) =>
      tester.widget<Text>(find.text(texto)).style!.fontSize!;

  testWidgets('sin subtítulo ni letra chica bajo cada razón', (tester) async {
    await abrir(tester);

    for (final ido in [
      'Así sabemos qué buses vienen hacia ti y te avisamos antes de que '
          'llegue el tuyo.',
      'Ves dónde va el tuyo, no dónde debería ir',
      'Calculado con la posición real del bus',
      'Suena cuando se acerca a tu punto de espera',
    ]) {
      expect(find.text(ido), findsNothing, reason: ido);
    }
  });

  testWidgets('el título y las razones van a su tamaño de encabezado',
      (tester) async {
    await abrir(tester);

    expect(
        tamano(tester, 'Activa tu ubicación'), AppTextStyles.display.fontSize);
    for (final razon in [
      'Buses en vivo',
      'A qué distancia viene',
      'Aviso antes de que llegue',
    ]) {
      expect(tamano(tester, razon), AppTextStyles.subtitulo.fontSize,
          reason: razon);
    }
  });

  testWidgets('el labio de la hoja proyecta su sombra hacia arriba',
      (tester) async {
    // La hoja está abajo y la noche arriba: la sombra que la separa cae
    // sobre la noche. `AppShadows.floating` es la de una tarjeta que flota
    // sobre el suelo —hacia abajo— y aquí se perdía bajo el borde de la
    // pantalla (R-14).
    await abrir(tester);

    final hoja = tester.widgetList<Container>(find.byType(Container)).where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).gradient is LinearGradient &&
              ((c.decoration! as BoxDecoration).gradient! as LinearGradient)
                      .colors
                      .first ==
                  AppColors.arenaAlta,
        );
    expect(hoja, hasLength(1));
    final sombras = (hoja.single.decoration! as BoxDecoration).boxShadow!;
    expect(sombras, isNotEmpty);
    for (final sombra in sombras) {
      expect(sombra.offset.dy, lessThan(0));
      expect(sombra.color, AppColors.primaryDeep.withValues(alpha: 0.08));
    }
  });
}
