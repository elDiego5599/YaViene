import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_pasajero/core/router/app_router.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/selected_buses_provider.dart';
import 'package:ya_viene_pasajero/features/viaje/entrada_del_viaje.dart';

void main() {
  Future<ProviderContainer> abrir(WidgetTester tester) async {
    final contenedor = ProviderContainer();
    addTearDown(contenedor.dispose);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            const Scaffold(body: Column(children: [EntradaDelViaje()])),
      ),
      GoRoute(
        path: AppRoutes.viaje,
        builder: (_, __) => const Text('el planificador'),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: contenedor,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return contenedor;
  }

  testWidgets('pregunta a dónde va y Planear abre el planificador',
      (tester) async {
    await abrir(tester);
    expect(find.text('¿A dónde vas?'), findsOneWidget);
    await tester.tap(find.text('Planear'));
    await tester.pumpAndSettle();
    expect(find.text('el planificador'), findsOneWidget);
  });

  testWidgets('con un bus tocado se va, y vuelve al soltarlo', (tester) async {
    final contenedor = await abrir(tester);
    contenedor.read(selectedBusesProvider.notifier).toggleBus('B-1');
    await tester.pumpAndSettle();
    expect(find.text('¿A dónde vas?'), findsNothing);
    contenedor.read(selectedBusesProvider.notifier).toggleBus('B-1');
    await tester.pumpAndSettle();
    expect(find.text('¿A dónde vas?'), findsOneWidget);
  });
}
