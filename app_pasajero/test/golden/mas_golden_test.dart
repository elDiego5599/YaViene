@Tags(['goldens'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/fondo_ilustrado.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/mas_screen.dart';

import 'golden_harness.dart';

/// La pestaña Info, con y sin ruta activa.
///
/// Sustituye al menú lateral (dueño, 2026-10-16): página entera en vez de
/// cajón, sin la X ni las filas de Avisos y Buzón, que ahora son pestañas.
/// Las ilustraciones de fondo (dueño, 2026-10-18) y las tarjetas blancas
/// con sombra en una columna angosta (dueño, 2026-10-16). Sin cuenta (D3),
/// la ruta activa es lo primero.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> abrir(WidgetTester tester, {RouteInfo? ruta}) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen<RouteInfo?>(selectedRouteProvider, (_, __) {});
    addTearDown(sub.close);
    if (ruta != null) {
      container.read(selectedRouteProvider.notifier).select(ruta);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: const Locale('es', 'CO'),
          // Quieto: el oro tiene que salir igual cada vez.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const MasScreen(),
        ),
      ),
    );
    // Las ilustraciones del fondo se decodifican fuera del reloj falso;
    // sin esto la foto saldría sin ellas.
    await tester.runAsync(() async {
      for (final m in Motivo.values) {
        if (m.asset == null) continue;
        await precacheImage(
            AssetImage(m.asset!), tester.element(find.byType(MasScreen)));
      }
    });
    await tester.pump();
  }

  testWidgets('Más · sin ruta activa', (tester) async {
    fijarPantalla(tester);
    await abrir(tester);
    await coincideConOro(tester, 'mas_sin_ruta');
  });

  testWidgets('Más · con ruta activa', (tester) async {
    fijarPantalla(tester);
    await abrir(
      tester,
      ruta: const RouteInfo(
        id: 'R-106',
        name: 'Ruta 106',
        companyId: 'EMP-01',
        terminalA: 'Mallorquín',
        terminalB: 'La Playa',
      ),
    );
    await coincideConOro(tester, 'mas_con_ruta');
  });
}
