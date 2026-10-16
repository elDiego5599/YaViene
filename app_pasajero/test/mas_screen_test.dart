import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/app_info.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/mas_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// La pestaña Más sola. El fondo de rutas anima sin fin, así que nada
  /// de `pumpAndSettle`: se bombea a mano.
  Future<ProviderContainer> abrirMas(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Mantiene vivo el provider autoDispose de la ruta seleccionada aunque
    // nadie lo mire antes de montar la pantalla.
    final sub = container.listen<RouteInfo?>(
      selectedRouteProvider,
      (_, __) {},
    );
    addTearDown(sub.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MasScreen()),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('abre con sus secciones',
      (tester) async {
    await abrirMas(tester);

    expect(find.text('Ya Viene'), findsOneWidget);
    expect(find.text('Sin ruta activa'), findsOneWidget);
    expect(find.text('Ver guía de uso'), findsOneWidget);
    // Avisos y el buzón son pestañas de la barra de abajo: aquí no se
    // repiten.
    expect(find.text('Avisos'), findsNothing);
    expect(find.text('Problemas y sugerencias'), findsNothing);
    // Sin cuenta (D3): ni saludo con el nombre ni «Cerrar sesión».
    expect(find.textContaining('Hola'), findsNothing);
    expect(find.text('Cerrar sesión'), findsNothing);
    // Sin EN VIVO ni versiones de relleno.
    expect(find.text('EN VIVO'), findsNothing);
  });

  testWidgets('con ruta activa muestra el nombre y la línea de terminales',
      (tester) async {
    final container = await abrirMas(tester);
    container.read(selectedRouteProvider.notifier).select(const RouteInfo(
          id: 'R1',
          name: 'B18 Tcherassi',
          companyId: 'C1',
          terminalA: 'Mallorquín',
          terminalB: 'La Playa',
        ));
    await tester.pump();

    expect(find.text('B18 Tcherassi'), findsOneWidget);
    expect(find.text('Mallorquín'), findsOneWidget);
    expect(find.text('La Playa'), findsOneWidget);
  });

  testWidgets('ruta con un solo terminal no dibuja línea incompleta',
      (tester) async {
    final container = await abrirMas(tester);
    container.read(selectedRouteProvider.notifier).select(const RouteInfo(
          id: 'R1',
          name: 'B18 Tcherassi',
          companyId: 'C1',
          terminalA: 'Mallorquín',
          terminalB: '',
        ));
    await tester.pump();

    expect(find.text('Mallorquín'), findsOneWidget);
  });

  testWidgets('nombre de ruta largo usa ellipsis en la tarjeta activa',
      (tester) async {
    final container = await abrirMas(tester);
    const longName =
        'Ruta Metropolitana Especial Terminal Norte Aeropuerto Internacional';
    container.read(selectedRouteProvider.notifier).select(const RouteInfo(
          id: 'R-LONG',
          name: longName,
          companyId: 'C1',
        ));
    await tester.pump();

    final routeText = tester.widget<Text>(find.text(longName));
    expect(routeText.maxLines, 1);
    expect(routeText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('Más lleva a los documentos y a la versión instalada',
      (tester) async {
    await abrirMas(tester);

    // Sin cuenta, Más es el único sitio estable donde volver a leer lo
    // que se aceptó en la bienvenida.
    expect(find.text('Privacidad'), findsOneWidget);
    expect(find.text('Términos'), findsOneWidget);
    expect(find.text('Acerca de'), findsOneWidget);
  });

  testWidgets('"Acerca de" dice qué versión está instalada', (tester) async {
    await abrirMas(tester);

    // En la pantalla de prueba (600 de alto) «Acerca de» puede quedar bajo
    // el borde: la página se desplaza para llegar.
    await tester.ensureVisible(find.text('Acerca de'));
    await tester.pump();
    await tester.tap(find.text('Acerca de'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining(kAppVersion), findsWidgets);
  });

  // El pie iba pegado al último grupo y debajo quedaba media pantalla de
  // tinta vacía. Ahora baja hasta el fondo de la página.
  testWidgets('el pie de Más se apoya abajo del todo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrirMas(tester);

    final pie = tester.getRect(find.textContaining('OpenStreetMap'));
    final pagina = tester.getRect(find.byType(MasScreen));
    expect(pagina.bottom - pie.bottom, lessThan(48));
  });

  testWidgets('en una pantalla baja el pie no se monta encima', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrirMas(tester);

    expect(tester.takeException(), isNull);
    await tester.dragUntilVisible(
      find.textContaining('OpenStreetMap'),
      find.byType(Scrollable).last,
      const Offset(0, -80),
    );
    // El fondo anima sin fin: se deja correr la inercia a mano.
    await tester.pump(const Duration(seconds: 1));
    final grupo = tester.getRect(find.text('Acerca de'));
    final pie = tester.getRect(find.textContaining('OpenStreetMap'));
    expect(pie.top, greaterThan(grupo.bottom));
  });
}
