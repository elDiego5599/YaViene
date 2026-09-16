@Tags(['goldens'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'app_drawer.dart';

import 'golden_harness.dart';

/// El menú lateral, con y sin ruta activa.
///
/// Once estilos escritos a mano sobre fondo ink. Es la superficie oscura
/// más grande de la app, así que aquí se ve enseguida si la migración de
/// tipografía cambia pesos o interletrado. Sin cuenta (D3) ya no lleva la
/// tarjeta con el nombre ni «Cerrar sesión»: la ruta activa es lo primero.
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
          home: const Scaffold(
            drawer: AppDrawer(),
            body: ColoredBox(color: Color(0xFFE8E6E1)),
          ),
        ),
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pump();
    // La entrada del menú es escalonada (560 ms de controlador repartidos en
    // ocho escalones). Se avanza en varios saltos y no en uno solo: un
    // único salto gigante le da al ticker un delta enorme y hay escalones
    // que se quedan a medias.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('menú · sin ruta activa', (tester) async {
    fijarPantalla(tester);
    await abrir(tester);
    await coincideConOro(tester, 'menu_sin_ruta');
  });

  testWidgets('menú · con ruta activa', (tester) async {
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
    await coincideConOro(tester, 'menu_con_ruta');
  });
}
