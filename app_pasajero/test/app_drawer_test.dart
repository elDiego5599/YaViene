import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/app_info.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/app_drawer.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> pumpDrawer(
    WidgetTester tester, {
    bool sinAnimaciones = false,
  }) async {
    final container = ProviderContainer();
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
      MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(disableAnimations: sinAnimaciones),
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              drawer: const AppDrawer(),
            ),
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

  /// La escala del botón de cierre a mitad de la entrada.
  double escalaDeLaX(WidgetTester tester) {
    final escala = tester.widget<ScaleTransition>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('drawer_close')),
            matching: find.byType(ScaleTransition),
          )
          .first,
    );
    return escala.scale.value;
  }

  /// Abre el drawer y se detiene dentro de la entrada, sin dejarla terminar.
  Future<void> abrirAMedias(WidgetTester tester) async {
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  testWidgets('la X entra creciendo y termina en su tamaño', (tester) async {
    await pumpDrawer(tester);
    await abrirAMedias(tester);
    expect(escalaDeLaX(tester), lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 700));
    expect(escalaDeLaX(tester), 1.0);
  });

  testWidgets('con movimiento reducido la X nace en su tamaño', (tester) async {
    await pumpDrawer(tester, sinAnimaciones: true);
    await abrirAMedias(tester);
    // Crecer es movimiento, y eso es lo que apaga «Reducir movimiento»: la
    // X nace ya en su tamaño y se queda ahí.
    expect(escalaDeLaX(tester), 1.0);

    await tester.pump(const Duration(milliseconds: 700));
    expect(escalaDeLaX(tester), 1.0);
  });

  testWidgets('abre con sus secciones y la entrada escalonada termina visible',
      (tester) async {
    await pumpDrawer(tester);
    await openDrawer(tester);

    expect(find.text('Ya Viene'), findsOneWidget);
    expect(find.text('Sin ruta activa'), findsOneWidget);
    expect(find.text('Avisos'), findsOneWidget);
    expect(find.text('Ver guía de uso'), findsOneWidget);
    // Sin cuenta (D3): ni saludo con el nombre ni «Cerrar sesión».
    expect(find.textContaining('Hola'), findsNothing);
    expect(find.text('Cerrar sesión'), findsNothing);
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

  testWidgets('el menú lleva a los documentos y a la versión instalada',
      (tester) async {
    await pumpDrawer(tester);
    await openDrawer(tester);

    // Sin cuenta, el menú es el único sitio estable donde volver a leer lo
    // que se aceptó en la bienvenida.
    expect(find.text('Privacidad'), findsOneWidget);
    expect(find.text('Términos'), findsOneWidget);
    expect(find.text('Acerca de'), findsOneWidget);
  });

  testWidgets('"Acerca de" dice qué versión está instalada', (tester) async {
    await pumpDrawer(tester);
    await openDrawer(tester);

    // Con el buzón en el grupo, «Acerca de» queda bajo el borde de la
    // pantalla de prueba (600 de alto): el menú se desplaza para llegar.
    await tester.ensureVisible(find.text('Acerca de'));
    await tester.pump();
    await tester.tap(find.text('Acerca de'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining(kAppVersion), findsWidgets);
  });

  // El pie iba pegado al último grupo y debajo quedaba media pantalla de
  // tinta vacía. Ahora baja hasta el fondo del menú.
  testWidgets('el pie del menú se apoya abajo del todo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpDrawer(tester);
    await openDrawer(tester);

    final pie = tester.getRect(find.textContaining('OpenStreetMap'));
    final menu = tester.getRect(find.byType(Drawer));
    expect(menu.bottom - pie.bottom, lessThan(48));
  });

  testWidgets('en una pantalla baja el pie no se monta encima', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpDrawer(tester);
    await openDrawer(tester);

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
