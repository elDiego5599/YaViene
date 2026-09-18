import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/search_pill_bar.dart';

void main() {
  testWidgets('el texto de la pill queda centrado', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // autoDispose: mantener vivo selectedRouteProvider con un listener.
    container.listen(selectedRouteProvider, (_, __) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SearchPillBar(),
            ),
          ),
        ),
      ),
    );

    final pill = tester.getRect(find.byType(SearchPillBar));
    final title = tester.getRect(find.text('¿Qué bus esperas?'));
    final subtitle = tester.getRect(find.text('Toca para buscar tu ruta'));
    expect((title.center.dx - pill.center.dx).abs(), lessThan(2));
    expect((subtitle.center.dx - pill.center.dx).abs(), lessThan(2));
    expect((title.center.dy - subtitle.center.dy).abs(), greaterThan(10));
  });

  testWidgets('la zona de búsqueda se anuncia como botón', (tester) async {
    final handle = tester.ensureSemantics();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(selectedRouteProvider, (_, __) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SearchPillBar(),
            ),
          ),
        ),
      ),
    );

    // Los dos botones de los lados ya se anunciaban; la mitad central —que
    // es la que abre el selector— no decía nada.
    expect(
      find.bySemanticsLabel('¿Qué bus esperas? Toca para buscar tu ruta'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('con ruta elegida, arriba dice «Ruta activa» y debajo la ruta',
      (tester) async {
    final handle = tester.ensureSemantics();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(selectedRouteProvider, (_, __) {});
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(
            id: 'R-106',
            name: 'Ruta 106',
            companyId: 'EMP-01',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SearchPillBar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // El dueño lo pidió así: la etiqueta encima, el nombre debajo, y sin el
    // «Toca para cambiar», que ya sobraba en una píldora que todo el mundo
    // sabe que se toca.
    final etiqueta = tester.getRect(find.text('Ruta activa'));
    final nombre = tester.getRect(find.text('Ruta 106'));
    expect(etiqueta.center.dy, lessThan(nombre.center.dy));
    expect(find.textContaining('Toca para cambiar'), findsNothing);
    expect(find.bySemanticsLabel('Ruta activa: Ruta 106'), findsOneWidget);
    handle.dispose();
  });
}
