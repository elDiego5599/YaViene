import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/search_pill_bar.dart';

void main() {
  const sobusa = Company(id: 'EMP-01', name: 'Sobusa');
  const ruta = RouteInfo(id: 'R-101', name: 'B18 Tcherassi', companyId: 'EMP-01');

  Future<ProviderContainer> pumpBar(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [
      companiesProvider.overrideWith((ref) async => const [sobusa]),
      routesByCompanyProvider.overrideWith(
        (ref, companyId) async => const [ruta],
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SearchPillBar()),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('con ruta activa, el X quita ruta Y empresa (queda en blanco)',
      (tester) async {
    final container = await pumpBar(tester);
    container.read(selectedCompanyProvider.notifier).select(sobusa);
    container.read(selectedRouteProvider.notifier).select(ruta);
    await tester.pump();

    expect(find.text('B18 Tcherassi'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(container.read(selectedRouteProvider), isNull,
        reason: 'el X debe quitar la ruta activa');
    expect(container.read(selectedCompanyProvider), isNull,
        reason: 'el X debe quitar también la empresa para dejar en blanco');
    expect(find.text('¿Qué bus esperas?'), findsOneWidget);
  });
}