import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/app_info.dart';
import 'package:ya_viene_pasajero/core/router/app_router.dart';
import 'package:ya_viene_pasajero/core/widgets/fondo_texturizado.dart';
import 'package:ya_viene_pasajero/core/widgets/titulo_seccion.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/fondo_ilustrado.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/mas_screen.dart';
import 'helpers/barra.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// La pestaña Info sola. El fondo de rutas anima sin fin, así que nada
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

  testWidgets('abre con sus secciones', (tester) async {
    await abrirMas(tester);
    expect(find.byType(FondoTexturizado), findsOneWidget);

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

  testWidgets('Info va en una columna angosta y centrada, no de borde a borde',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrirMas(tester);

    // «Se ve todo muy ancho» (dueño, 2026-10-16): las tarjetas no pasan de
    // 360 aunque el teléfono sea grande, y quedan al centro.
    final tarjeta = tester.getRect(find.byType(ActiveRouteCard));
    expect(tarjeta.width, lessThanOrEqualTo(360));
    expect((tarjeta.center.dx - 215).abs(), lessThan(0.5));
    final grupo = tester.getRect(find
        .ancestor(
          of: find.text('Privacidad'),
          matching: find.byType(Container),
        )
        .last);
    expect(grupo.width, lessThanOrEqualTo(360));
  });

  testWidgets('las tarjetas blancas de Info se despegan con sombra',
      (tester) async {
    await abrirMas(tester);

    for (final texto in ['Sin ruta activa', 'Ver guía de uso', 'Privacidad']) {
      final decoradas = tester
          .widgetList<Container>(find.ancestor(
            of: find.text(texto),
            matching: find.byType(Container),
          ))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          // La tarjeta es la superficie redondeada; el fondo de cada fila
          // (su respuesta al toque) va adentro, sin esquinas.
          .where((d) => d.borderRadius != null);
      final tarjeta = decoradas.first;
      expect(tarjeta.color, AppColors.surface, reason: texto);
      expect(tarjeta.boxShadow, isNotEmpty, reason: texto);
    }
  });

  // «Quita la pill de MapLibre y eso ponlo dentro de Acerca de» (dueño,
  // 2026-10-18): la página acaba en su último grupo.
  testWidgets('los créditos del mapa van en Acerca de, no sueltos en Info',
      (tester) async {
    await abrirMas(tester);
    expect(find.textContaining('OpenStreetMap'), findsNothing);

    await tester.ensureVisible(find.text('Acerca de'));
    await tester.pump();
    await tester.tap(find.text('Acerca de'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining(kAppVersion), findsWidgets);
    expect(
        find.textContaining(
            '©\u00A0MapLibre, ©\u00A0OpenStreetMap, ©\u00A0CARTO'),
        findsOneWidget);
  });

  testWidgets('cada grupo de Info lleva su título de sección', (tester) async {
    await abrirMas(tester);
    double y(Finder f) => tester.getTopLeft(f).dy;
    for (final (titulo, primeraFila) in [
      ('Ayuda', 'Ver guía de uso'),
      ('Información', 'Privacidad'),
    ]) {
      final t = find.text(titulo);
      expect(find.ancestor(of: t, matching: find.byType(TituloSeccion)),
          findsOneWidget,
          reason: titulo);
      expect(y(t), lessThan(y(find.text(primeraFila))), reason: titulo);
    }
    expect(y(find.text('Ayuda')),
        greaterThan(tester.getRect(find.byType(ActiveRouteCard)).bottom));
  });

  testWidgets('en una pantalla baja se llega al último grupo sin desbordes',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrirMas(tester);

    expect(tester.takeException(), isNull);
    await tester.dragUntilVisible(
      find.text('Acerca de'),
      find.byType(Scrollable).last,
      const Offset(0, -80),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  // «Mejor con las fotos animadas» (dueño, 2026-10-18): las ilustraciones
  // en vez del mosaico, con la marca y los créditos en su píldora blanca
  // para que se lean encima.
  testWidgets('Info lleva las ilustraciones, con la letra sobre blanco',
      (tester) async {
    await abrirMas(tester);

    expect(find.byType(FondoIlustrado), findsOneWidget);
    // Los dibujos se apagan antes de que acabe la tarjeta de la ruta: lo
    // demás va sobre el blanco limpio.
    expect(FondoIlustrado.franja,
        lessThanOrEqualTo(tester.getRect(find.byType(ActiveRouteCard)).bottom));
    for (final (texto, color) in [
      ('Ya Viene', AppColors.textPrimary),
    ]) {
      final letra = find.textContaining(texto);
      expect(tester.widget<Text>(letra).style!.color, color);
      final pildora = tester.widget<DecoratedBox>(find
          .ancestor(of: letra, matching: find.byKey(MasScreen.pildoraKey))
          .first);
      final fondo = (pildora.decoration as BoxDecoration).color!;
      expect(fondo, AppColors.surface, reason: texto);
      expect(fondo.a, 1, reason: '$texto: la píldora es opaca');
    }
    // Fondo claro arriba: la hora y la batería en oscuro.
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
    expect(region.value, SystemUiOverlayStyle.dark);
  });

  testWidgets('al bajar, «Ya Viene» se queda y lo de abajo pasa bajo la barra',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrirMas(tester);

    final antes = tester.getRect(find.text('Ya Viene'));
    // La barra de vidrio, como en Avisos y Buzón (dueño, 2026-10-18): la
    // marca va en ella y no se desplaza.
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('Ya Viene')),
        findsOneWidget);
    await exigeBarraVidrio(tester, find.byType(ActiveRouteCard));
    expect(tester.getRect(find.text('Ya Viene')), antes);
  });

  testWidgets('en reposo la tarjeta queda a 26 de la marca', (tester) async {
    await abrirMas(tester);

    expect(
        tester.getRect(find.byType(ActiveRouteCard)).top -
            tester
                .getRect(find.descendant(
                    of: find.byType(AppBar),
                    matching: find.byKey(MasScreen.pildoraKey)))
                .bottom,
        moreOrLessEquals(26, epsilon: 0.5));
  });

  /// La tarjeta parece un botón: tocarla lleva al mapa (revisión externa,
  /// 2026-10-18: «la tarjeta de ruta activa no lleva al mapa»). Sin ruta,
  /// además abre el selector, como «Escoge empresa y ruta» en la hoja.
  Future<ProviderContainer> abrirConMapa(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subs = [
      container.listen<RouteInfo?>(selectedRouteProvider, (_, __) {}),
      container.listen<int>(pedirSelectorProvider, (_, __) {}),
    ];
    addTearDown(() {
      for (final s in subs) {
        s.close();
      }
    });
    final router = GoRouter(initialLocation: '/info', routes: [
      GoRoute(path: '/info', builder: (_, __) => const MasScreen()),
      GoRoute(path: AppRoutes.map, builder: (_, __) => const Text('el mapa')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    return container;
  }

  testWidgets('la tarjeta de la ruta activa lleva al mapa', (tester) async {
    final container = await abrirConMapa(tester);
    container.read(selectedRouteProvider.notifier).select(const RouteInfo(
          id: 'R1',
          name: 'B18 Tcherassi',
          companyId: 'C1',
          terminalA: 'Mallorquín',
          terminalB: 'La Playa',
        ));
    await tester.pump();
    expect(
        tester.getSemantics(find.byType(ActiveRouteCard)),
        matchesSemantics(
            isButton: true,
            hasTapAction: true,
            label: 'Ruta activa: B18 Tcherassi, entre Mallorquín y La Playa',
            hint: 'Ver en el mapa'));

    await tester.tap(find.byType(ActiveRouteCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('el mapa'), findsOneWidget);
    expect(container.read(pedirSelectorProvider), 0,
        reason: 'con ruta no se abre el selector');
  });

  testWidgets('sin ruta, la tarjeta abre el selector en el mapa',
      (tester) async {
    final container = await abrirConMapa(tester);
    await tester.tap(find.byType(ActiveRouteCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('el mapa'), findsOneWidget);
    expect(container.read(pedirSelectorProvider), 1);
  });
}
