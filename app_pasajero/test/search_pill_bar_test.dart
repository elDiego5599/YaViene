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
}
