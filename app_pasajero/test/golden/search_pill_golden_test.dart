import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'search_pill_bar.dart';

import 'golden_harness.dart';

/// La píldora de búsqueda, que es lo primero que se ve sobre el mapa.
///
/// Va sobre un fondo gris neutro y no sobre el mapa de verdad: el mapa es
/// una vista nativa que en pruebas no se pinta, y lo que se vigila aquí es
/// la píldora, no el mapa.
void main() {
  Future<ProviderContainer> montar(
    WidgetTester tester, {
    RouteInfo? ruta,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // `selectedRouteProvider` es autoDispose: sin un oyente se descarta y
    // deja un temporizador pendiente que el marco de pruebas denuncia.
    container.listen(selectedRouteProvider, (_, __) {});
    if (ruta != null) {
      container.read(selectedRouteProvider.notifier).select(ruta);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: marcoGolden(
          const ColoredBox(
            color: Color(0xFFE8E6E1),
            child: Align(
              alignment: Alignment.topCenter,
              child: SearchPillBar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('píldora sin ruta elegida', (tester) async {
    fijarPantalla(tester);
    await montar(tester);
    await coincideConOro(tester, 'pildora_sin_ruta');
  });

  testWidgets('píldora con ruta activa', (tester) async {
    fijarPantalla(tester);
    await montar(
      tester,
      ruta: const RouteInfo(
        id: 'R-106',
        name: 'Ruta 106 · Centro',
        companyId: 'EMP-01',
      ),
    );
    await coincideConOro(tester, 'pildora_con_ruta');
  });
}
