import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/router/app_router.dart';
import 'package:ya_viene_pasajero/core/widgets/aviso.dart';
import 'package:ya_viene_pasajero/core/widgets/pildora_navegacion.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/realtime_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/mas_screen.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/alert_history_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:ya_viene_pasajero/features/tarjeta/presentation/tarjeta_screen.dart';
import 'package:ya_viene_pasajero/services/background_keep_alive.dart';

import 'helpers/mapa.dart';

/// La guía puesta en un paso, sin pasar por las preferencias.
class _GuiaEn extends MapGuideNotifier {
  _GuiaEn(MapGuideState estado) {
    state = estado;
  }
}

/// La barra de abajo con las cuatro pestañas, como en Instagram (dueño,
/// 2026-10-16): Mapa, Avisos, Tarjeta e Info. Reemplaza el menú lateral.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(GoRouter, ProviderContainer)> abrir(
    WidgetTester tester,
    String ruta, {
    MapGuideState guia = const MapGuideState(initialized: true),
    Set<String> avisos = const {},
    double escala = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      // Lo del mapa, sin red ni GPS ni plugins, como en `MapaDePrueba`.
      backendUrlProvider.overrideWith(() => BackendUrl.fija('http://x')),
      realtimeServiceProvider.overrideWithValue(RepoDePrueba()),
      userLocationProvider.overrideWith((ref) => UbicacionDePrueba()),
      servicioDeFondoProvider.overrideWithValue(ServicioDePrueba()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => const Stream.empty(),
      ),
      proximityAlertsProvider.overrideWith(
        (ref) => ProximityAlertsNotifier(ref,
            notify: ({
              required String busId,
              String? routeName,
              String? routeId,
              String? companyId,
              required int distanceMeters,
            }) async =>
                true),
      ),
      mapGuideProvider.overrideWith((ref) => _GuiaEn(guia)),
    ]);
    addTearDown(container.dispose);
    for (final id in avisos) {
      container.read(activeAlertsProvider.notifier).activateAlert(id);
    }
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    router.go(ruta);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            padding: const EdgeInsets.only(top: 47, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
            textScaler: TextScaler.linear(escala),
            // El fondo de Más (la red de rutas) se mueve sin parar; quieto,
            // `pumpAndSettle` termina.
            disableAnimations: true,
          ),
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (router, container);
  }

  /// Como `MapaDePrueba.desmontar`: el mapa deja temporizadores que tienen
  /// que vencer antes de que la prueba termine.
  Future<void> desmontarMapa(
      WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.read(proximityAlertsProvider.notifier).stop();
    await tester.pump(const Duration(seconds: 10));
  }

  String camino(GoRouter router) =>
      router.routeInformationProvider.value.uri.path;

  test('las cuatro pestañas son ramas de un shell y lo legal va encima', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    final shell =
        router.configuration.routes.whereType<StatefulShellRoute>().single;
    final ramas =
        shell.branches.map((b) => (b.routes.single as GoRoute).path).toList();
    expect(ramas, ['/map', '/notifications', '/tarjeta', '/mas']);
    // Privacidad y términos se abren por encima de la barra, con su flecha.
    expect(
      router.configuration.routes.whereType<GoRoute>().map((r) => r.path),
      contains('/legal/:doc'),
    );
  });

  test('cada pestaña con su dibujo, sin los tres puntos (dueño, 2026-10-16)',
      () {
    // «Más» con tres puntos no decía nada: la cuarta es «Info», con su i.
    // El mapa lleva el pin de lugar, y la tarjeta la suya de crédito
    // (el buzón se fue a Info, 2026-11-14).
    expect(kPestanas.map((p) => (p.rotulo, p.icono, p.iconoPuesto)), [
      ('Mapa', Icons.location_on_outlined, Icons.location_on_rounded),
      ('Avisos', Icons.notifications_none_rounded, Icons.notifications_rounded),
      ('Tarjeta', Icons.credit_card_outlined, Icons.credit_card_rounded),
      ('Info', Icons.info_outline_rounded, Icons.info_rounded),
    ]);
  });

  testWidgets('la barra dice sus cuatro pestañas y cuál está puesta',
      (tester) async {
    await abrir(tester, '/notifications');

    expect(find.byType(PildoraNavegacion), findsOneWidget);
    for (final r in ['Mapa', 'Avisos', 'Tarjeta', 'Info']) {
      expect(
        find.descendant(
          of: find.byType(PildoraNavegacion),
          matching: find.text(r),
        ),
        findsOneWidget,
      );
    }
    final avisos = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'^Avisos, pestaña 2 de 4')));
    expect(avisos.flagsCollection.isSelected, Tristate.isTrue);
    expect(avisos.flagsCollection.isButton, isTrue);
    final mapa =
        tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Mapa, pestaña')));
    expect(mapa.flagsCollection.isSelected, Tristate.isFalse);
  });

  testWidgets('tocar una pestaña lleva a su pantalla', (tester) async {
    final (router, _) = await abrir(tester, '/notifications');

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Info, pestaña')));
    await tester.pumpAndSettle();
    expect(camino(router), '/mas');
    expect(find.byType(MasScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Tarjeta, pestaña')));
    await tester.pumpAndSettle();
    expect(camino(router), '/tarjeta');
    expect(find.byType(TarjetaScreen), findsOneWidget);
  });

  testWidgets('con un aviso activo, la pestaña lleva la cuenta',
      (tester) async {
    await abrir(tester, '/mas', avisos: {'b1'});

    expect(
      find.descendant(
        of: find.byType(PildoraNavegacion),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'^Avisos, 1 activo, pestaña 2 de 4')),
        findsOneWidget);
  });

  testWidgets('con la guía puesta la barra se aparta', (tester) async {
    await abrir(
      tester,
      '/notifications',
      guia: const MapGuideState(initialized: true, step: MapGuideStep.search),
    );

    expect(find.byType(PildoraNavegacion), findsNothing);
  });

  testWidgets('con la bienvenida abierta la barra se aparta', (tester) async {
    await abrir(
      tester,
      '/notifications',
      guia: const MapGuideState(initialized: true, bienvenida: true),
    );

    expect(find.byType(PildoraNavegacion), findsNothing);
  });

  testWidgets('lo de cada pestaña termina encima de la barra', (tester) async {
    await abrir(tester, '/notifications');

    final arriba = tester.getTopLeft(find.byType(PildoraNavegacion)).dy;
    final abajo =
        MediaQuery.paddingOf(tester.element(find.byType(NotificationsScreen)))
            .bottom;
    expect(844 - abajo, lessThanOrEqualTo(arriba));
  });

  testWidgets('como pestaña, Avisos no trae flecha de volver', (tester) async {
    await abrir(tester, '/notifications');

    expect(find.byTooltip('Volver'), findsNothing);
  });

  testWidgets('con el texto al triple la barra no se desborda', (tester) async {
    await abrir(tester, '/notifications', escala: 3);

    expect(tester.takeException(), isNull);
    expect(find.byType(PildoraNavegacion), findsOneWidget);
  });

  testWidgets('Info ya no trae Avisos, Tarjeta ni la X del menú',
      (tester) async {
    await abrir(tester, '/mas');

    expect(find.byKey(const ValueKey('drawer_close')), findsNothing);
    final enMas = find.descendant(
      of: find.byType(MasScreen),
      matching: find.byType(Text),
    );
    final textos = tester.widgetList<Text>(enMas).map((t) => t.data).toList();
    expect(textos, isNot(contains('Avisos')));
    expect(textos, isNot(contains('Tarjeta')));
    expect(
        textos,
        containsAll([
          'Ver guía de uso',
          'Problemas y sugerencias',
          'Privacidad',
          'Términos',
          'Acerca de'
        ]));
  });

  testWidgets(
      'en el mapa la barra se funde con la hoja, salvo con el '
      'selector arriba', (tester) async {
    final (_, container) = await abrir(tester, '/map');
    bool fundida() => tester
        .widget<PildoraNavegacion>(find.byType(PildoraNavegacion))
        .fundida;

    expect(fundida(), isTrue);
    container.read(routeSelectorOpenProvider.notifier).state = true;
    await tester.pump();
    expect(fundida(), isFalse, reason: 'la hoja se aparta y la barra es suya');
    await desmontarMapa(tester, container);
  });

  // «Cuando borro un aviso o selecciono avisos la pill se solapa con el de
  // deshacer y un botón» (dueño, 2026-10-16). Al seleccionar, la barra se
  // aparta como en Fotos de iPhone y el botón de borrar queda a la vista,
  // sobre la barra de inicio.
  testWidgets('al seleccionar avisos la barra se aparta y deja ver Borrar',
      (tester) async {
    final (_, container) = await abrir(tester, '/notifications');
    container
        .read(alertHistoryProvider.notifier)
        .upsert('A-1', routeId: 'R1', radioM: 1000);
    await tester.pumpAndSettle();
    final pantalla = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsScreen)));
    pantalla.read(alertSelectionProvider.notifier).enter();
    await tester.pumpAndSettle();

    expect(find.byType(PildoraNavegacion), findsNothing);
    final boton = tester.getRect(find.ancestor(
        of: find.text('Selecciona avisos'),
        matching: find.byWidgetPredicate((w) => w is ElevatedButton)));
    expect(boton.bottom, lessThanOrEqualTo(844 - 34));

    pantalla.read(alertSelectionProvider.notifier).clear();
    await tester.pumpAndSettle();
    expect(find.byType(PildoraNavegacion), findsOneWidget);
  });

  testWidgets('el aviso de abajo («Deshacer») sale encima de la barra',
      (tester) async {
    await abrir(tester, '/notifications');
    mostrarAviso(
        tester.element(find.byType(NotificationsScreen)), 'Aviso borrado',
        accion: ('Deshacer', (_) {}));
    await tester.pumpAndSettle();

    final barra = tester.getRect(find.byType(PildoraNavegacion));
    expect(tester.getRect(find.byType(AvisoTarjeta)).bottom,
        lessThanOrEqualTo(barra.top));
  });

  // «Cuando borro un aviso la pill de abajo queda solapando el cuadrito
  // del mensaje de deshacer» (dueño, 2026-10-18): se borra seleccionando,
  // con la barra apartada; el aviso sale y la barra vuelve debajo de él.
  // El aviso sigue a la barra mientras se ve, no la mide una vez al salir.
  testWidgets('el «Deshacer» sube cuando la barra vuelve, y baja si se va',
      (tester) async {
    await abrir(tester, '/notifications');
    final pantalla = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsScreen)));
    pantalla.read(alertSelectionProvider.notifier).enter();
    await tester.pumpAndSettle();
    expect(find.byType(PildoraNavegacion), findsNothing);

    mostrarAviso(
        tester.element(find.byType(NotificationsScreen)), 'Aviso borrado',
        accion: ('Deshacer', (_) {}));
    pantalla.read(alertSelectionProvider.notifier).clear();
    await tester.pumpAndSettle();

    final barra = tester.getRect(find.byType(PildoraNavegacion));
    expect(tester.getRect(find.byType(AvisoTarjeta)).bottom,
        lessThanOrEqualTo(barra.top));

    // Y al revés: si la barra se aparta, el aviso no se queda flotando
    // donde ella estaba.
    pantalla.read(alertSelectionProvider.notifier).enter();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AvisoTarjeta)).bottom,
        greaterThan(barra.top));
  });

  testWidgets('con el «Deshacer» abajo, la barra sigue respondiendo',
      (tester) async {
    final (router, _) = await abrir(tester, '/notifications');
    mostrarAviso(
        tester.element(find.byType(NotificationsScreen)), 'Aviso borrado',
        accion: ('Deshacer', (_) {}));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
        of: find.byType(PildoraNavegacion), matching: find.text('Tarjeta')));
    await tester.pumpAndSettle();
    expect(camino(router), '/tarjeta');
  });

  testWidgets('con la rueda de la distancia abierta la barra se aparta',
      (tester) async {
    final (_, container) = await abrir(tester, '/map');
    expect(find.byType(PildoraNavegacion), findsOneWidget);

    container.read(eligiendoDistanciaProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(find.byType(PildoraNavegacion), findsNothing,
        reason: 'la rueda y sus dos botones no caben con la barra debajo');

    container.read(eligiendoDistanciaProvider.notifier).state = false;
    await tester.pumpAndSettle();
    expect(find.byType(PildoraNavegacion), findsOneWidget);
    await desmontarMapa(tester, container);
  });

  testWidgets('fuera del mapa la barra lleva su filo y su sombra',
      (tester) async {
    await abrir(tester, '/notifications');

    expect(
        tester
            .widget<PildoraNavegacion>(find.byType(PildoraNavegacion))
            .fundida,
        isFalse);
  });

  group('la barra sola', () {
    Future<List<int>> montar(WidgetTester tester, {int indice = 1}) async {
      final elegidas = <int>[];
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: StatefulBuilder(
              builder: (context, setState) => PildoraNavegacion(
                indice: indice,
                alElegir: (i) {
                  elegidas.add(i);
                  setState(() => indice = i);
                },
              ),
            ),
          ),
        ),
      ));
      return elegidas;
    }

    Offset centroDe(WidgetTester tester, String rotulo) => tester.getCenter(
          find.descendant(
            of: find.byType(PildoraNavegacion),
            matching: find.text(rotulo),
          ),
        );

    testWidgets(
        'fundida, la barra es parte de la hoja: sin fondo, filo ni '
        'sombra propios', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child:
                PildoraNavegacion(indice: 0, fundida: true, alElegir: (_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final caja = tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(PildoraNavegacion),
        matching: find.byType(AnimatedContainer),
      ));
      final fondo = caja.decoration! as BoxDecoration;
      expect(fondo.color!.a, 0);
      expect(fondo.border, isNull);
      expect(fondo.boxShadow, anyOf(isNull, isEmpty));
    });

    testWidgets('tocar la pestaña puesta no hace nada', (tester) async {
      final elegidas = await montar(tester);

      await tester.tap(find.text('Avisos'));
      await tester.pumpAndSettle();
      expect(elegidas, isEmpty);
    });

    testWidgets('al deslizar el dedo se va pasando de pestaña en pestaña',
        (tester) async {
      final toques = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (llamada) async {
          if (llamada.method == 'HapticFeedback.vibrate') {
            toques.add(llamada.arguments as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final elegidas = await montar(tester);

      final desde = centroDe(tester, 'Avisos');
      final hasta = centroDe(tester, 'Info');
      final dedo = await tester.startGesture(desde);
      for (var i = 1; i <= 20; i++) {
        await dedo.moveTo(Offset.lerp(desde, hasta, i / 20)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await dedo.up();
      await tester.pumpAndSettle();

      // Pasa por Tarjeta antes de llegar a Info, y cada paso se siente.
      expect(elegidas, [2, 3]);
      expect(toques, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.selectionClick',
      ]);
    });

    testWidgets('deslizar de vuelta regresa a la pestaña de antes',
        (tester) async {
      final elegidas = await montar(tester, indice: 2);

      final desde = centroDe(tester, 'Tarjeta');
      final hasta = centroDe(tester, 'Mapa');
      final dedo = await tester.startGesture(desde);
      for (var i = 1; i <= 20; i++) {
        await dedo.moveTo(Offset.lerp(desde, hasta, i / 20)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await dedo.up();
      await tester.pumpAndSettle();

      expect(elegidas, [1, 0]);
    });

    testWidgets('el dedo fuera de la barra se queda en la última pestaña',
        (tester) async {
      final elegidas = await montar(tester, indice: 2);

      final desde = centroDe(tester, 'Tarjeta');
      final dedo = await tester.startGesture(desde);
      for (var i = 1; i <= 20; i++) {
        await dedo.moveTo(desde + Offset(30.0 * i, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await dedo.up();
      await tester.pumpAndSettle();

      expect(elegidas, [3]);
    });
  });
}
