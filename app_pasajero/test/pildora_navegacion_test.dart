import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/core/router/app_router.dart';
import 'package:ya_viene_pasajero/core/widgets/pildora_navegacion.dart';
import 'package:ya_viene_pasajero/features/buzon/presentation/buzon_screen.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/mas_screen.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/screens/notifications_screen.dart';

/// La guía puesta en un paso, sin pasar por las preferencias.
class _GuiaEn extends MapGuideNotifier {
  _GuiaEn(MapGuideState estado) {
    state = estado;
  }
}

/// La barra de abajo con las cuatro pestañas, como en Instagram (dueño,
/// 2026-10-16): Mapa, Avisos, Buzón y Más. Reemplaza el menú lateral.
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
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => const Stream.empty(),
      ),
      proximityAlertsProvider.overrideWith(
        (ref) => ProximityAlertsNotifier(ref,
            notify: ({
              required String busId,
              String? routeName,
              String? routeId,
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
    expect(ramas, ['/map', '/notifications', '/buzon', '/mas']);
    // Privacidad y términos se abren por encima de la barra, con su flecha.
    expect(
      router.configuration.routes.whereType<GoRoute>().map((r) => r.path),
      contains('/legal/:doc'),
    );
  });

  testWidgets('la barra dice sus cuatro pestañas y cuál está puesta',
      (tester) async {
    await abrir(tester, '/notifications');

    expect(find.byType(PildoraNavegacion), findsOneWidget);
    for (final r in ['Mapa', 'Avisos', 'Buzón', 'Más']) {
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

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Más, pestaña')));
    await tester.pumpAndSettle();
    expect(camino(router), '/mas');
    expect(find.byType(MasScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Buzón, pestaña')));
    await tester.pumpAndSettle();
    expect(camino(router), '/buzon');
    expect(find.byType(BuzonScreen), findsOneWidget);
  });

  testWidgets('con avisos puestos, la pestaña lleva la cuenta', (tester) async {
    await abrir(tester, '/mas', avisos: {'b1', 'b2'});

    expect(
      find.descendant(
        of: find.byType(PildoraNavegacion),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'^Avisos, 2 activos, pestaña 2 de 4')),
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

  testWidgets('Más ya no trae Avisos, Buzón ni la X del menú', (tester) async {
    await abrir(tester, '/mas');

    expect(find.byKey(const ValueKey('drawer_close')), findsNothing);
    final enMas = find.descendant(
      of: find.byType(MasScreen),
      matching: find.byType(Text),
    );
    final textos = tester.widgetList<Text>(enMas).map((t) => t.data).toList();
    expect(textos, isNot(contains('Avisos')));
    expect(textos, isNot(contains('Problemas y sugerencias')));
    expect(
        textos,
        containsAll(
            ['Ver guía de uso', 'Privacidad', 'Términos', 'Acerca de']));
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
      final hasta = centroDe(tester, 'Más');
      final dedo = await tester.startGesture(desde);
      for (var i = 1; i <= 20; i++) {
        await dedo.moveTo(Offset.lerp(desde, hasta, i / 20)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await dedo.up();
      await tester.pumpAndSettle();

      // Pasa por Buzón antes de llegar a Más, y cada paso se siente.
      expect(elegidas, [2, 3]);
      expect(toques, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.selectionClick',
      ]);
    });

    testWidgets('deslizar de vuelta regresa a la pestaña de antes',
        (tester) async {
      final elegidas = await montar(tester, indice: 2);

      final desde = centroDe(tester, 'Buzón');
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

      final desde = centroDe(tester, 'Buzón');
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
