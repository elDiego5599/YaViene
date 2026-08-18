import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ya_viene_pasajero/main.dart' as app;

/// Flujos reales de la pasajero contra Firebase y el backend reales (túnel),
/// desde una instalación limpia. Cobertura anti-tontos:
/// 1) registro con correo nuevo (botón "Regístrate") → onboarding → mapa;
/// 2) el placeholder "Preparando tu mapa…" se funde (regresión del bug del
///    placeholder eterno);
/// 3) selección de ruta desde el buscador (empresa Sobusa → ruta);
/// 4) drawer → Avisos → volver (regresa al drawer abierto) → cerrar con la X;
/// 5) Cerrar sesión → login;
/// 6) volver a entrar con la cuenta ya creada (usuario que vuelve) → mapa.
///
/// main() es `void main() async`: no se puede await; el arranque async
/// sigue corriendo mientras el test espera por frames reales. Un solo
/// testWidgets porque main() (y Firebase.initializeApp) no se repiten.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flujos reales: registro, ruta, notificaciones, logout y login',
      (tester) async {
    // El tour de primer uso (coach mark sobre la píldora y sobre el botón de
    // aviso del bus) intercepta los toques: se marca como visto para que el
    // flujo automatizado no se detenga. El tour ya se cubre en los widget
    // tests (test/map_tour_test.dart).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('map_tour_seen', true);
    await prefs.setBool('map_tour_bus_seen', true);

    app.main();

    // 1) Pantalla de login (instalación limpia).
    await _waitUntil(
      tester,
      () => find.text('Iniciar con Google').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 60),
      message: 'no apareció la pantalla de login',
    );

    // Registro por el botón "¿No tienes cuenta? Regístrate" (nuevo camino).
    final email = 'qa${DateTime.now().millisecondsSinceEpoch}@yaviene.app';
    const password = 'Demo123456';
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await _waitUntil(
      tester,
      () => find.text('Crear cuenta').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'el botón Regístrate no llevó al paso de crear cuenta',
    );
    // Sin correo escrito aún: el botón de volver debe decir "Regresar", no
    // "Cambiar de correo" (no hay correo que cambiar).
    expect(find.text('Cambiar de correo'), findsNothing);
    expect(find.text('Regresar'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'QA Tester');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña (mín. 6)'), password);
    await tester.enterText(
        find.widgetWithText(TextField, 'Repite la contraseña'), password);
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

    // 3) Selección de ruta desde el buscador.
    await _waitUntil(
      tester,
      () => find.text('¿Qué bus esperas?').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'no apareció el buscador de ruta',
    );
    await tester.tap(find.text('¿Qué bus esperas?'));
    await _waitUntil(
      tester,
      () => find.text('Elige tu ruta').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'no abrió el selector de ruta',
    );
    await _waitUntil(
      tester,
      () => find.text('Selecciona una empresa').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'no cargaron las empresas',
    );
    await tester.tap(find.text('Selecciona una empresa'));
    await _waitUntil(
      tester,
      () => find.text('Sobusa').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'no cargaron las empresas',
    );
    await tester.tap(find.text('Sobusa'));
    await _waitUntil(
      tester,
      () => find.text('Selecciona una ruta').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'no apareció la tarjeta de ruta tras elegir empresa',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Selecciona una ruta'));
    await _waitUntil(
      tester,
      () => find.text('B18 Tcherassi').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'no cargaron las rutas',
    );
    await tester.tap(find.text('B18 Tcherassi'));
    await _waitUntil(
      tester,
      () => find.text('Ruta activa • Toca para cambiar').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'la ruta no quedó activa',
    );
    // La hoja "Elige tu ruta" permanece abierta tras elegir; se cierra al
    // tocar fuera (barrera). La descartamos tocando la parte superior (en
    // coordenadas lógicas del device).
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(size.width / 2, size.height * 0.12));
    await _waitUntil(
      tester,
      () => find.text('Elige tu ruta').evaluate().isEmpty,
      timeout: const Duration(seconds: 10),
      message: 'la hoja de ruta no se cerró',
    );
    await tester.pump(const Duration(milliseconds: 500));

    // 4) Drawer → Avisos → volver: el back regresa AL DRAWER abierto (no al
    //    mapa), porque el drawer no se cierra antes de navegar.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await _waitUntil(
      tester,
      () => find.text('Avisos').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
      message: 'no abrió el drawer',
    );
    await tester.tap(find.text('Avisos'));
    await _waitUntil(
      tester,
      () => find.text('No tienes avisos activos').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'la pantalla de notificaciones no abrió',
    );
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await _waitUntil(
      tester,
      () => find.text('Avisos').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'el back no volvió al drawer abierto',
    );
    // Cierre explícito con la X del header del drawer (la hoja ETA también
    // tiene una X en pantalla; la del drawer está identificada por Key).
    await tester.tap(find.byKey(const ValueKey('drawer_close')));
    await _waitUntil(
      tester,
      () =>
          find.byIcon(Icons.menu_rounded).evaluate().isNotEmpty &&
          tester.getCenter(find.byIcon(Icons.menu_rounded)).dx > 30,
      timeout: const Duration(seconds: 15),
      message: 'la X no cerró el drawer',
    );

    // 5) Cerrar sesión → login.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await _waitUntil(
      tester,
      () => find.text('Cerrar sesión').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
      message: 'no abrió el drawer para cerrar sesión',
    );
    await tester.tap(find.text('Cerrar sesión'));
    await _waitUntil(
      tester,
      () => find.text('Iniciar con Google').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
      message: 'no se llegó a la pantalla de login tras cerrar sesión',
    );
    // Anti-tontos: ya sin sesión no debe existir ningún botón para saltarse
    // el inicio de sesión y colarse al mapa.
    expect(find.text('Saltar inicio de sesión (Modo Pruebas)'), findsNothing);

    // 6) Volver a entrar con la cuenta ya creada (usuario que vuelve).
    await tester.enterText(find.byType(TextField).first, email);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Continuar'));
    await _waitUntil(
      tester,
      () => find.text('Entrar').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
      message: 'la cuenta existente no llegó al paso de contraseña',
    );
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña'), password);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Entrar'));
    await _waitUntil(
      tester,
      () => find.byIcon(Icons.menu_rounded).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 45),
      message: 'no se volvió al mapa tras entrar',
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