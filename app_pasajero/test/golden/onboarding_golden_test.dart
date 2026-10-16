@Tags(['goldens'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/features/onboarding/presentation/screens/'
    'onboarding_screen.dart';

import 'golden_harness.dart';

/// La bienvenida: la primera pantalla con la que alguien conoce la app.
void main() {
  testWidgets('bienvenida', (tester) async {
    SharedPreferences.setMockInitialValues({});
    fijarPantalla(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: marcoGoldenRuteado(const OnboardingScreen()),
      ),
    );
    // La malla del fondo respira sin parar: con un salto fijo desde el
    // arranque sale siempre en el mismo punto del ciclo.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await coincideConOro(tester, 'bienvenida');
  });
}
