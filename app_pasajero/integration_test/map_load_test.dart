import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ya_viene_pasajero/main.dart' as app;

/// Flujos reales de la pasajero contra Firebase y el backend reales (túnel),
/// desde una instalación limpia:
/// 1) registro con correo nuevo → onboarding → mapa;
/// 2) el placeholder "Preparando tu mapa…" se funde (regresión del bug del
///    placeholder eterno);
/// 3) drawer → Notificaciones → volver;
/// 4) drawer → Cerrar sesión → pantalla de login (ejercita resetAppState).
///
/// main() es `void main() async`: no se puede await; el arranque async
/// sigue corriendo mientras el test espera por frames reales. Un solo
/// testWidgets porque main() (y Firebase.initializeApp) no se repiten.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flujos reales: registro, mapa, notificaciones y logout',
      (tester) async {
    app.main();

    // 1) Pantalla de login (instalación limpia).
    await _waitUntil(
      tester,
      () => find.text('Iniciar con Google').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 60),
      message: 'no apareció la pantalla de login',
    );

    // Registro: correo nuevo → Continuar.
    final email =
        'qa${DateTime.now().millisecondsSinceEpoch}@yaviene.app';
    await tester.enterText(find.byType(TextField).first, email);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Continuar'));

    // checkEmail con Firebase en modo anti-enumeración devuelve "el correo
    // ya existe" incluso para correos nuevos (el probe falla con
    // 'invalid-credential' y se trata como existente). El registro real se
    // alcanza por el enlace "¿No tienes cuenta? Crea una con este correo".
    await _waitUntil(
      tester,
      () =>
          find.text('Entrar').evaluate().isNotEmpty ||
          find.text('Crear cuenta').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
      message: 'no avanzó tras Continuar (checkEmail o UI falló)',
    );
    if (find.text('Entrar').evaluate().isNotEmpty) {
      await tester.tap(find.text('¿No tienes cuenta? Crea una con este correo'));
    }

    // Paso de perfil: nombre, contraseña, confirmar. El campo Email sigue
    // presente (deshabilitado), así que se blanquea por hint, no por índice.
    await _waitUntil(
      tester,
      () => find.text('Crear cuenta').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'no llegó al paso de perfil',
    );
    await tester.enterText(
        find.widgetWithText(TextField, 'Nombre'), 'QA Tester');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña (mín. 6)'), 'Demo123456');
    await tester.enterText(
        find.widgetWithText(TextField, 'Repite la contraseña'), 'Demo123456');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Crear cuenta'));

    // Onboarding (primera vez) o directo al mapa.
    await _waitUntil(
      tester,
      () =>
          find.text('Ahora no').evaluate().isNotEmpty ||
          find.byIcon(Icons.menu_rounded).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 45),
      message: 'ni onboarding ni mapa tras el registro',
    );
    if (find.text('Ahora no').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ahora no'));
    }

    // 2) El mapa con su menú, y el placeholder que debe fundirse.
    await _waitUntil(
      tester,
      () => find.byIcon(Icons.menu_rounded).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 45),
      message: 'no apareció el menú del mapa',
    );
    final placeholder = find.text('Preparando tu mapa…');
    await _waitUntil(
      tester,
      () => placeholder.evaluate().isEmpty,
      timeout: const Duration(seconds: 45),
      message: 'el placeholder quedó fijo; el estilo del mapa no cargó',
    );

    // 3) Drawer → Notificaciones → volver.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Notificaciones'));
    await _waitUntil(
      tester,
      () => find.text('No tienes avisos activos').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'la pantalla de notificaciones no abrió',
    );
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await _waitUntil(
      tester,
      () => find.byIcon(Icons.menu_rounded).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'no se volvió al mapa',
    );

    // 4) Cerrar sesión → login.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Cerrar sesión'));
    await _waitUntil(
      tester,
      () => find.text('Iniciar con Google').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
      message: 'no se llegó a la pantalla de login tras cerrar sesión',
    );

    // Sin excepciones no capturadas en todo el recorrido.
    expect(tester.takeException(), isNull);
  });
}

/// Espera real (no pumpAndSettle, que se cuelga con timers periódicos) hasta
/// que [cond] se cumpla o venza [timeout].
Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() cond, {
  required Duration timeout,
  String? message,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (cond()) return;
  }
  fail(message ?? 'tiempo de espera agotado');
}

/// Devuelve los textos visibles de la pantalla (diagnóstico).
String _visibleTexts(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((t) => t.isNotEmpty)
      .toList();
  return texts.join(' | ');
}