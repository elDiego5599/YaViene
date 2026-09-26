import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ya_viene_pasajero/main.dart' as app;

/// Flujos reales de la pasajero contra el backend real (túnel), desde una
/// instalación limpia. Cobertura anti-tontos:
/// 1) arranque → bienvenida (primera vez) → mapa, sin cuenta ni inicio de
///    sesión (D3);
/// 2) el placeholder "Preparando tu mapa…" se funde (regresión del bug del
///    placeholder eterno);
/// 3) selección de ruta desde el buscador (empresa Sobusa → ruta);
/// 4) drawer → Avisos → volver (regresa al drawer abierto) → cerrar con la X;
/// 5) el menú no ofrece cerrar sesión: no hay cuenta que cerrar.
///
/// main() es `void main() async`: no se puede await; el arranque async
/// sigue corriendo mientras el test espera por frames reales. Un solo
/// testWidgets porque main() no se repite.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flujos reales sin cuenta: bienvenida, ruta y avisos',
      (tester) async {
    app.main();

    // 1) Del arranque a la bienvenida (primera vez) o directo al mapa. No
    //    hay pantalla de inicio de sesión en el camino.
    await _waitUntil(
      tester,
      () =>
          find.text('Ahora no').evaluate().isNotEmpty ||
          find.byIcon(Icons.menu_rounded).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 60),
      message: 'ni bienvenida ni mapa tras el arranque',
    );
    expect(find.text('Iniciar con Google'), findsNothing);
    if (find.text('Ahora no').evaluate().isNotEmpty) {
      // Desde a3971ac los dos botones de la bienvenida están apagados hasta
      // marcar la casilla de privacidad/términos: primero se acepta, después
      // «Ahora no». Sin la casilla el toque es muerto y el mapa nunca abre.
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 400));
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
    // Paso 1: el tile de empresa abre su lista. Antes esta prueba tocaba
    // "Selecciona una empresa" estando todavía en la vista principal: era
    // copy del botón muerto que la hoja tenía antes del rediseño, y hoy
    // ese texto solo existe dentro de la lista. El tile en sí es
    // `companiesAsync.when`: con la petición todavía en vuelo es un
    // placeholder sin el texto, así que hay que esperar a que cargue.
    await _waitUntil(
      tester,
      () => find.text('Empresa').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
      message: 'no apareció el tile de empresa (¿la petición no cargó?)',
    );
    await tester.tap(find.text('Empresa'));
    await _waitUntil(
      tester,
      () => find.text('Sobusa').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'no cargaron las empresas',
    );
    await tester.tap(find.text('Sobusa'));
    await _waitUntil(
      tester,
      () => find.text('Ruta').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'no apareció la tarjeta de ruta tras elegir empresa',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Ruta'));
    // Desde 0ad4ce2 el tile de la lista separa el código del nombre: el
    // badge dice «B18» y el título es «Tcherassi». El nombre completo
    // «B18 Tcherassi» solo está en la tarjeta de la vista principal ya
    // elegida, así que aquí se busca por el título visible.
    await _waitUntil(
      tester,
      () => find.text('Tcherassi').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      message: 'no cargaron las rutas',
    );
    await tester.tap(find.text('Tcherassi'));
    await _waitUntil(
      tester,
      () => find.text('Ruta activa').evaluate().isNotEmpty,
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
    // 5) Sin cuenta no hay sesión que cerrar.
    expect(find.text('Cerrar sesión'), findsNothing);
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
