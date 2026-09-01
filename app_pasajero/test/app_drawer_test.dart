import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/providers/auth_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/app_drawer.dart';

/// Fake de autenticación sin Firebase: el drawer solo lee `state`.
class _FakeAuth implements AuthNotifier {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #state) {
      return const AuthState(
        status: AuthStatus.verified,
        email: 'qa@yaviene.app',
        name: 'QA Tester',
      );
    }
    return null;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> pumpDrawer(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => _FakeAuth()),
    ]);
    addTearDown(container.dispose);
    // Mantiene vivo el provider autoDispose de la ruta seleccionada mientras
    // el drawer está cerrado (sin listeners); si no, seleccionar y luego
    // abrir el drawer no se verían.
    final sub = container.listen<RouteInfo?>(
      selectedRouteProvider,
      (_, __) {},
    );
    addTearDown(sub.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(),
            drawer: const AppDrawer(),
          ),
        ),
      ),
    );
    return container;
  }

  Future<void> openDrawer(WidgetTester tester) async {
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('abre con sus secciones y la entrada escalonada termina visible',
      (tester) async {
    await pumpDrawer(tester);
    await openDrawer(tester);

    expect(find.text('Ya Viene'), findsOneWidget);
    expect(find.text('Hola, QA'), findsOneWidget);
    expect(find.text('qa@yaviene.app'), findsOneWidget);
    expect(find.text('Sin ruta activa'), findsOneWidget);
    expect(find.text('Avisos'), findsOneWidget);
    expect(find.text('Ver guía de uso'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    // Sin EN VIVO ni versiones de relleno.
    expect(find.text('EN VIVO'), findsNothing);
  });

  testWidgets('la X cierra el drawer', (tester) async {
    await pumpDrawer(tester);
    await openDrawer(tester);
    expect(find.text('Avisos'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('drawer_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Avisos'), findsNothing);
  });

  testWidgets('con ruta activa muestra el nombre y la línea de terminales',
      (tester) async {
    final container = await pumpDrawer(tester);
    container.read(selectedRouteProvider.notifier).select(const RouteInfo(
          id: 'R1',
          name: 'B18 Tcherassi',
          companyId: 'C1',
          terminalA: 'Mallorquín',
          terminalB: 'La Playa',
        ));
    await tester.pump();
    await openDrawer(tester);

    expect(find.text('B18 Tcherassi'), findsOneWidget);
    expect(find.text('Mallorquín'), findsOneWidget);
    expect(find.text('La Playa'), findsOneWidget);
  });

  testWidgets('ruta con un solo terminal no dibuja línea incompleta',
      (tester) async {
    final container = await pumpDrawer(tester);
    container.read(selectedRouteProvider.notifier).select(const RouteInfo(
          id: 'R1',
          name: 'B18 Tcherassi',
          companyId: 'C1',
          terminalA: 'Mallorquín',
          terminalB: '',
        ));
    await tester.pump();
    await openDrawer(tester);

    expect(find.text('Mallorquín'), findsOneWidget);
  });

  testWidgets('nombre de ruta largo usa ellipsis en la tarjeta activa',
      (tester) async {
    final container = await pumpDrawer(tester);
    const longName =
        'Ruta Metropolitana Especial Terminal Norte Aeropuerto Internacional';
    container.read(selectedRouteProvider.notifier).select(const RouteInfo(
          id: 'R-LONG',
          name: longName,
          companyId: 'C1',
        ));
    await tester.pump();
    await openDrawer(tester);

    final routeText = tester.widget<Text>(find.text(longName));
    expect(routeText.maxLines, 1);
    expect(routeText.overflow, TextOverflow.ellipsis);
  });
}
