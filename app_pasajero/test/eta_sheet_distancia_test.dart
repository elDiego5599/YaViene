// La hoja con la distancia del aviso elegida por la persona (dueño,
// 2026-10-06): el primer aviso pregunta con la rueda, en la misma tarjeta
// del bus y no en una ventana encima; después, una fila
// «Te avisamos a … · Cambiar» bajo el botón deja cambiarla (en iPhone, con
// el aviso activo, va en la nota de encima), y cambiarla también mueve el
// aviso que está sonando por ese bus.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/aviso.dart';
import 'package:ya_viene_pasajero/core/widgets/cifra_viva.dart';
import 'package:ya_viene_pasajero/core/widgets/dialogo.dart';
import 'package:ya_viene_pasajero/core/widgets/pildora_navegacion.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/alert_toggle_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_recenter_button.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/distancia_aviso_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

const _lat = 6.2442;
const _lon = -75.5812;

/// Un bus a [metros] al norte del pin (un grado de latitud son 111.195 m
/// con el radio de la Tierra de `haversineMeters`).
BusPosition _busA(double metros) => BusPosition(
      busId: 'A-1',
      routeId: 'R1',
      lat: _lat + metros / 111195,
      lon: _lon,
      heading: 0,
      speedKmh: 25,
      timestamp: DateTime.now(),
      isGhostBus: false,
    );

void main() {
  /// Monta la hoja con el bus A-1 a [metros] y, si hay, la distancia
  /// [guardada] en el teléfono. El permiso de notificaciones se concede: lo
  /// que se prueba es la distancia, no el permiso.
  Future<ProviderContainer> montar(
    WidgetTester tester, {
    double metros = 4000,
    int? guardada,
    Size tamano = const Size(390, 844),
    double escala = 1,
    ValueChanged<bool>? alEligiendo,
    Stream<List<BusPosition>>? posiciones,
    double rutaKm = 0,
    double? barra,
  }) async {
    SharedPreferences.setMockInitialValues(
      {
        if (guardada != null) 'distancia_aviso_m': guardada,
        'explicacion_aviso_cercania_oculta': true,
      },
    );
    // Un iPhone 13 salvo que la prueba pida otro.
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
          (ref, routeId) => posiciones ?? Stream.value([_busA(metros)])),
      // Por defecto el recorrido pasa por el pin; [rutaKm] lo corre al sur,
      // lejos del bus, que va al norte.
      routeTrajectoryProvider.overrideWith(
        (ref, routeId) => RouteTrajectory(
          routeId: routeId,
          routeName: 'Ruta 1',
          points: [
            GeoPoint(lat: _lat - rutaKm * 1000 / 111195, lon: _lon - 0.05),
            GeoPoint(lat: _lat - rutaKm * 1000 / 111195, lon: _lon + 0.05),
          ],
        ),
      ),
      alertToggleProvider.overrideWith(
        (ref) =>
            AlertToggleController(ref, requestPermission: () async => true),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            // [barra]: dentro de las pestañas, con la barra en la hoja.
            child: barra == null
                ? child!
                : PildoraVisible(visible: barra, child: child!),
          ),
          // Abajo, como en el mapa: la hoja crece hacia arriba.
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: EtaBottomSheet(onEligiendoDistancia: alEligiendo),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: _lat,
        lon: _lon,
      ),
    );
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
        );
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> girarA(WidgetTester tester, int metros) async {
    final rueda = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    rueda.scrollController!.jumpToItem((metros - 500) ~/ 100);
    await tester.pumpAndSettle();
  }

  int ruedaEn(WidgetTester tester) => tester
      .widget<CupertinoPicker>(find.byType(CupertinoPicker))
      .scrollController!
      .selectedItem;

  final fila = find.byKey(const ValueKey('cambiar-distancia'));
  final tarjeta = find.byKey(const ValueKey('hoja-tarjeta'));
  final rueda = find.byType(CupertinoPicker);

  group('el primer aviso pregunta la distancia', () {
    testWidgets('«Guardar» arma el aviso a esa distancia y la deja guardada',
        (tester) async {
      final c = await montar(tester);
      expect(fila, findsNothing,
          reason: 'sin distancia guardada ni aviso no hay nada que cambiar');

      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      expect(find.text('¿A qué distancia te avisamos?'), findsOneWidget);
      expect(ruedaEn(tester), 5, reason: 'arranca en el kilómetro de siempre');
      expect(find.text('Solo esta vez'), findsOneWidget);

      await girarA(tester, 1800);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(c.read(activeAlertsProvider), contains('A-1'));
      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 1800);
      expect(c.read(distanciaAvisoProvider), 1800);
      expect(find.text('Aviso activado'), findsOneWidget);
      expect(find.text('Te avisamos a 1,8 km'), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);
    });

    testWidgets('«Solo esta vez» arma el aviso sin guardar la distancia',
        (tester) async {
      final c = await montar(tester);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      await girarA(tester, 600);
      await tester.tap(find.text('Solo esta vez'));
      await tester.pumpAndSettle();

      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 600);
      expect(c.read(distanciaAvisoProvider), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('distancia_aviso_m'), isFalse);
      // El aviso de este bus sí suena a 600 m: la fila lo dice.
      expect(find.text('Te avisamos a 600 m'), findsOneWidget);
    });

    // «Que salga en la misma card en vez de un popup nuevo» (dueño,
    // 2026-10-06): la tarjeta del bus cambia a la rueda, sin velo ni
    // ventana, y la placa se queda donde estaba.
    testWidgets('pregunta en la tarjeta del bus, sin ventana encima',
        (tester) async {
      await montar(tester);
      final placa = tester.getRect(find.byKey(const ValueKey('hoja-placa')));
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialogo), findsNothing);
      expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          isFalse,
          reason: 'no hay nada encima de la página del mapa');
      expect(find.descendant(of: tarjeta, matching: rueda), findsOneWidget);
      expect(
        find.descendant(
            of: tarjeta, matching: find.text('¿A qué distancia te avisamos?')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('hoja-placa')), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey('hoja-placa'))).width,
          placa.width);
      // Mientras pregunta, el botón del aviso deja su sitio a «Guardar».
      expect(find.text('Avisarme cuando esté cerca'), findsNothing);
      expect(find.byType(CifraViva), findsNothing);
      // Los dos botones, bajo la tarjeta y dentro de la pantalla.
      final guardar = tester.getRect(find.text('Guardar'));
      expect(guardar.top, greaterThan(tester.getRect(tarjeta).bottom));
      expect(tester.getRect(find.text('Solo esta vez')).top,
          greaterThan(guardar.bottom));
      expect(tester.getRect(find.text('Solo esta vez')).bottom,
          lessThanOrEqualTo(844));
    });

    testWidgets('el cambio a la rueda y de vuelta se anima', (tester) async {
      await montar(tester);
      final antes = tester.getRect(tarjeta).height;
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final aMedias = tester.getRect(tarjeta).height;
      await tester.pumpAndSettle();
      final despues = tester.getRect(tarjeta).height;
      expect(despues, greaterThan(antes));
      expect(aMedias, inExclusiveRange(antes, despues),
          reason: 'la tarjeta crece, no salta');
    });

    testWidgets('girar la rueda con el dedo cambia la distancia',
        (tester) async {
      final c = await montar(tester);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      // Hacia arriba sube la distancia.
      await tester.drag(rueda, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final radio = c.read(proximityAlertsProvider.notifier).radioDe('A-1')!;
      expect(radio, greaterThan(1000));
      expect(radio % 100, 0);
    });

    testWidgets('soltar el bus mientras pregunta no arma nada ni dice nada',
        (tester) async {
      final c = await montar(tester);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      c.read(selectedBusesProvider.notifier).toggleBus('A-1');
      await tester.pumpAndSettle();

      expect(rueda, findsNothing);
      expect(find.byType(AvisoTarjeta), findsNothing);
      expect(c.read(activeAlertsProvider), isEmpty);
      // Y al volver al bus, la tarjeta es la de siempre.
      c.read(selectedBusesProvider.notifier).toggleBus('A-1');
      await tester.pumpAndSettle();
      expect(rueda, findsNothing);
      expect(find.text('Avisarme cuando esté cerca'), findsOneWidget);
    });

    testWidgets('«atrás» cierra la rueda sin armar nada', (tester) async {
      final c = await montar(tester);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(rueda, findsNothing);
      expect(c.read(activeAlertsProvider), isEmpty);
      expect(find.text('Avisarme cuando esté cerca'), findsOneWidget);
    });

    // La guía tapa con su velo todo lo que no sea el botón del aviso: con
    // la rueda en la tarjeta, la rueda quedaría debajo sin poder girarse.
    testWidgets('le dice a la guía cuándo está preguntando', (tester) async {
      final avisos = <bool>[];
      await montar(tester, alEligiendo: avisos.add);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      expect(avisos, [true]);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(avisos, [true, false]);
    });

    testWidgets('con el texto al doble cabe entera con sus dos botones',
        (tester) async {
      await montar(tester, escala: 2);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // La fila crece con el texto: la cifra elegida no se recorta.
      expect(tester.widget<CupertinoPicker>(rueda).itemExtent,
          greaterThanOrEqualTo(tester.getSize(find.text('1,0 km')).height));
      expect(tester.getRect(find.text('Solo esta vez')).bottom,
          lessThanOrEqualTo(844));
      expect(tester.getRect(find.byKey(const ValueKey('hoja-placa'))).top,
          greaterThanOrEqualTo(0));
    });

    testWidgets('cabe entera en el teléfono más bajo', (tester) async {
      await montar(tester, tamano: const Size(320, 568));
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('Solo esta vez')).bottom,
          lessThanOrEqualTo(568));
      expect(tester.getRect(find.byKey(const ValueKey('hoja-placa'))).top,
          greaterThanOrEqualTo(0));
    });

    // La línea del tope suma alto: con el texto al doble y en el teléfono
    // más bajo, la tarjeta sigue entera.
    for (final (tamano, escala) in [
      (const Size(390, 844), 2.0),
      (const Size(320, 568), 1.0),
    ]) {
      testWidgets('con el tope dicho también cabe ($tamano ×$escala)',
          (tester) async {
        await montar(tester, metros: 950, tamano: tamano, escala: escala);
        await tester.tap(find.text('Avisarme cuando esté cerca'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Hasta 700 m'), findsOneWidget);
        expect(tester.getRect(find.text('Solo esta vez')).bottom,
            lessThanOrEqualTo(tamano.height));
        expect(tester.getRect(find.byKey(const ValueKey('hoja-placa'))).top,
            greaterThanOrEqualTo(0));
      });
    }

    // «0,7 a 1,2 km», con la punta de abajo en km, es la línea más larga:
    // en una sola línea y con la tarjeta entera, con el texto al doble y en el
    // teléfono más bajo.
    for (final (tamano, escala) in [
      (const Size(390, 844), 2.0),
      (const Size(320, 568), 1.0),
    ]) {
      testWidgets('con las dos puntas dichas también cabe ($tamano ×$escala)',
          (tester) async {
        await montar(tester,
            metros: 1450, rutaKm: 0.65, tamano: tamano, escala: escala);
        await tester.tap(find.text('Avisarme cuando esté cerca'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final linea = find.text('0,7 a 1,2 km');
        final alto =
            AppTextStyles.pie.fontSize! * AppTextStyles.pie.height! * escala;
        expect(tester.getSize(linea).height, closeTo(alto, 1),
            reason: 'una sola línea');
        expect(tester.getRect(find.text('Solo esta vez')).bottom,
            lessThanOrEqualTo(tamano.height));
        expect(tester.getRect(find.byKey(const ValueKey('hoja-placa'))).top,
            greaterThanOrEqualTo(0));
      });
    }

    // Con el aviso puesto y la barra dentro de la hoja, la tarjeta del bus
    // pasa del alto de la pantalla en el teléfono más bajo y con el texto
    // al doble: no se sale, se desplaza por dentro (no se pliega, así que
    // no hay arrastre que robarle).
    for (final (tamano, escala) in [
      (const Size(320, 568), 1.0),
      (const Size(390, 844), 2.0),
    ]) {
      testWidgets(
          'con el aviso puesto y la barra no se sale '
          '($tamano ×$escala)', (tester) async {
        await montar(tester,
            metros: 1250, tamano: tamano, escala: escala, barra: 1);
        await tester.tap(find.text('Avisarme cuando esté cerca'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Solo esta vez'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final tarjeta = tester.getRect(find
            .ancestor(
              of: find.byKey(const ValueKey('sheet-handle')),
              matching: find.byWidgetPredicate(
                  (w) => w is DecoratedBox && w.decoration is ShapeDecoration),
            )
            .first);
        expect(tarjeta.top, greaterThanOrEqualTo(0));
        expect(tarjeta.bottom, lessThanOrEqualTo(tamano.height));
        await tester.dragUntilVisible(
          fila,
          find.byKey(const ValueKey('sheet-handle')),
          const Offset(0, -100),
        );
        expect(tester.getRect(fila).bottom,
            lessThanOrEqualTo(tarjeta.bottom - PildoraNavegacion.alto));
      });
    }

    // Como la barra, el botón de recentrar se aparta mientras la rueda
    // pregunta, y vuelve cuando se contesta.
    testWidgets('con la rueda abierta el botón de recentrar se aparta',
        (tester) async {
      await montar(tester, metros: 1250);
      expect(find.byType(MapRecenterButton), findsOneWidget);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      expect(find.byType(MapRecenterButton), findsNothing);
      await tester.tap(find.text('Solo esta vez'));
      await tester.pumpAndSettle();
      expect(find.byType(MapRecenterButton), findsOneWidget);
    });

    testWidgets('«Cambiar» con el tope dicho cabe en el teléfono más bajo',
        (tester) async {
      await montar(tester,
          metros: 1250, guardada: 800, tamano: const Size(320, 568));
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Hasta 1,0 km'), findsOneWidget);
      expect(
          tester.getRect(find.text('Cancelar')).bottom, lessThanOrEqualTo(568));
      expect(tester.getRect(find.byKey(const ValueKey('hoja-placa'))).top,
          greaterThanOrEqualTo(0));
    });

    testWidgets('los botones se tocan con el pulgar', (tester) async {
      await montar(tester);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      for (final b in [FilledButton, TextButton]) {
        expect(tester.getSize(find.byType(b)).height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('el título se anuncia como encabezado', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('¿A qué distancia te avisamos?')),
        matchesSemantics(
            label: '¿A qué distancia te avisamos?', isHeader: true),
      );
      semantica.dispose();
    });

    testWidgets('con la distancia guardada no vuelve a preguntar',
        (tester) async {
      final c = await montar(tester, guardada: 2200);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialogo), findsNothing);
      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 2200);
    });
  });

  group('«Cambiar»', () {
    Future<void> activar(WidgetTester tester) async {
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
    }

    // Sin aviso puesto no hay nada que cambiar: la distancia se pregunta al
    // activarlo, y una fila que la ofrece antes confunde (dueño,
    // 2026-10-06).
    testWidgets('sin el aviso activo no dice la distancia ni la ofrece',
        (tester) async {
      await montar(tester, guardada: 2000);
      expect(find.text('Te avisamos a 2,0 km'), findsNothing);
      expect(find.text('Cambiar'), findsNothing);
      expect(fila, findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('sin el aviso activo tampoco en iPhone', (tester) async {
      await montar(tester, guardada: 2000);
      expect(find.text('Te avisamos a 2,0 km'), findsNothing);
      expect(find.text('Cambiar'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('abre la rueda en la distancia de ahora, con «Cancelar»',
        (tester) async {
      await montar(tester, guardada: 2000);
      await activar(tester);
      expect(find.text('Te avisamos a 2,0 km'), findsOneWidget);

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialogo), findsNothing);
      expect(
        find.descendant(
            of: tarjeta, matching: find.text('Distancia del aviso')),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Solo esta vez'), findsNothing);
      expect(ruedaEn(tester), 15, reason: 'abre en la distancia de ahora');
    });

    // «Cambiar» se pinta como «Quitar» en la píldora de la ubicación
    // (`PildoraEstado` con `actionDanger`), pero en rojo (dueño,
    // 2026-10-06).
    testWidgets('«Cambiar» es una píldora como «Quitar», en rojo',
        (tester) async {
      await montar(tester, guardada: 1500);
      await activar(tester);
      final pildora = find.ancestor(
          of: find.text('Cambiar'), matching: find.byType(Container));
      final caja =
          tester.widget<Container>(pildora.first).decoration! as BoxDecoration;
      expect(caja.color, AppColors.surfaceMuted);
      expect(caja.borderRadius, BorderRadius.circular(AppRadius.pill));
      expect(caja.border, Border.all(color: AppColors.hairline));
      final texto = tester.widget<Text>(find.text('Cambiar')).style!;
      expect(texto.color, AppColors.coralAccessible);
      expect(contraste(texto.color!, AppColors.surfaceMuted),
          greaterThanOrEqualTo(4.5));
    });

    testWidgets('«Cancelar» deja la distancia como estaba', (tester) async {
      final c = await montar(tester, guardada: 2000);
      await activar(tester);
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      await girarA(tester, 700);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(c.read(distanciaAvisoProvider), 2000);
      expect(find.text('Te avisamos a 2,0 km'), findsOneWidget);
    });

    testWidgets('con el aviso activo cambia ese aviso y lo dice',
        (tester) async {
      final c = await montar(tester, guardada: 1800);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 1800);

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      expect(find.text('Solo se cambia la distancia de este aviso'),
          findsOneWidget);
      await girarA(tester, 2500);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 2500);
      expect(c.read(distanciaAvisoProvider), 2500);
      expect(c.read(activeAlertsProvider), contains('A-1'));
      expect(find.text('Te avisamos a 2,5 km'), findsOneWidget);
    });

    testWidgets('con el aviso de «Solo esta vez», la fila dice la del aviso',
        (tester) async {
      final c = await montar(tester, guardada: 2000);
      c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
      c
          .read(proximityAlertsProvider.notifier)
          .armAlert('A-1', 'R1', radioM: 700);
      await tester.pumpAndSettle();

      // Lo que va a sonar es el aviso de 700 m, no la guardada.
      expect(find.text('Te avisamos a 700 m'), findsOneWidget);
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      expect(ruedaEn(tester), 2);
    });

    testWidgets('se lee como un botón y se toca con el pulgar', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, guardada: 1500);
      await activar(tester);

      expect(
        tester.getSemantics(fila),
        matchesSemantics(
          label: 'Te avisamos a 1,5 kilómetros. Cambiar la distancia',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(tester.getSize(fila).height, greaterThanOrEqualTo(48));
      semantica.dispose();
    });

    // «Cambiar» se mide contra su píldora, en la prueba de arriba.
    testWidgets('la distancia de la fila contrasta con la hoja (WCAG AA)',
        (tester) async {
      await montar(tester, guardada: 1500);
      await activar(tester);
      final color =
          tester.widget<Text>(find.text('Te avisamos a 1,5 km')).style!.color!;
      expect(contraste(color, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    // iPhone sale cuando haya avisos por push (dueño, 2026-10-06): la nota
    // «Deja Ya Viene abierta y la pantalla encendida» sobra, y su sitio,
    // justo encima del botón, lo toma la distancia con su «Cambiar».
    testWidgets('en iPhone, con el aviso activo, va en la nota sobre el botón',
        (tester) async {
      final semantica = tester.ensureSemantics();
      final c = await montar(tester, guardada: 1500);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      expect(c.read(activeAlertsProvider), contains('A-1'));

      expect(find.text('Deja Ya Viene abierta y la pantalla encendida'),
          findsNothing);
      final nota = find.byKey(const ValueKey('hoja-nota'));
      expect(
        find.descendant(of: nota, matching: find.text('Te avisamos a 1,5 km')),
        findsOneWidget,
      );
      expect(find.descendant(of: nota, matching: find.text('Cambiar')),
          findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget,
          reason: 'no se repite bajo el botón');
      expect(tester.getRect(nota).bottom,
          lessThan(tester.getRect(find.text('Aviso activado')).top));
      expect(
        tester.getSemantics(fila),
        matchesSemantics(
          label: 'Te avisamos a 1,5 kilómetros. Cambiar la distancia',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(tester.getSize(fila).height, greaterThanOrEqualTo(48));
      semantica.dispose();

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      expect(find.text('Distancia del aviso'), findsOneWidget);
      await girarA(tester, 900);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 900);
      expect(
        find.descendant(of: nota, matching: find.text('Te avisamos a 900 m')),
        findsOneWidget,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('con el bus sin señal la fila sigue bajo el botón',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'distancia_aviso_m': 1500,
        'explicacion_aviso_cercania_oculta': true,
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _TestUserLocation()),
        busPositionsSourceProvider.overrideWith(
          (ref, routeId) => Stream.value([
            BusPosition(
              busId: 'A-1',
              routeId: 'R1',
              lat: _lat + 0.03,
              lon: _lon,
              heading: 0,
              speedKmh: 0,
              timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
              isGhostBus: true,
            ),
          ]),
        ),
      ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: EtaBottomSheet())),
      ));
      (c.read(userLocationProvider.notifier) as _TestUserLocation).set(
        const UserLocationState(
            mode: UserLocationMode.manual, lat: _lat, lon: _lon),
      );
      c.read(selectedRouteProvider.notifier).select(
            const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
          );
      c.read(selectedBusesProvider.notifier).toggleBus('A-1');
      // El aviso se puso antes de que el bus perdiera la señal.
      c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
      c
          .read(proximityAlertsProvider.notifier)
          .armAlert('A-1', 'R1', radioM: 1500);
      await tester.pumpAndSettle();

      expect(find.text('Aviso activado'), findsOneWidget);
      expect(find.text('Te avisamos a 1,5 km'), findsOneWidget);
    });
  });

  group('la hoja mide con la distancia elegida', () {
    // «Hay alarmas de 500 m pero cuando el bus está a 1 km o menos sale que
    // ya está cerca» (dueño, 2026-10-07): con el bus a 1,65 km y 2 km
    // guardados, el aviso de 2 km sonaría ya mismo, pero uno que deje los
    // 200 m de margen, 1,4 km o menos, todavía sirve. La rueda llega hasta
    // ahí y no más.
    testWidgets('con la guardada por encima del bus, la rueda llega hasta él',
        (tester) async {
      final c = await montar(tester, metros: 1650, guardada: 2000);
      expect(find.text('El bus ya está cerca'), findsNothing);

      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      expect(rueda, findsOneWidget);
      expect(find.text('Hasta 1,4 km'), findsOneWidget);
      expect(ruedaEn(tester), 9, reason: 'arranca en la mayor que sirve');
      expect(find.text('1,5 km'), findsNothing);
      expect(find.text('2,0 km'), findsNothing);

      await girarA(tester, 1200);
      await tester.tap(find.text('Solo esta vez'));
      await tester.pumpAndSettle();
      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 1200);
      expect(c.read(distanciaAvisoProvider), 2000);
    });

    testWidgets('«Cambiar» tampoco ofrece lo que el bus ya pasó',
        (tester) async {
      final c = await montar(tester, metros: 1250, guardada: 800);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(find.text('Hasta 1,0 km'), findsOneWidget);
      expect(find.text('1,1 km'), findsNothing);
      await girarA(tester, 1000);
      expect(find.text('1,1 km'), findsNothing,
          reason: 'debajo de la última no asoma ninguna');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 1000);
    });

    // «El bus ya va a 2,4 km y aún puedo poner 2,6 km si ya estaba
    // adentro» (dueño, 2026-10-07): el tope sigue al bus mientras la rueda
    // está abierta, no se queda en el de cuando se abrió.
    testWidgets('el tope sigue al bus con la rueda abierta', (tester) async {
      final bus = StreamController<List<BusPosition>>();
      addTearDown(bus.close);
      final c = await montar(tester, guardada: 2000, posiciones: bus.stream);
      bus.add([_busA(2450)]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      expect(find.text('Hasta 2,2 km'), findsOneWidget);
      expect(ruedaEn(tester), 15, reason: 'en la del aviso, 2 km');

      // Se acerca a 1,85 km: 2 km ya sonaría, así que la rueda baja sola a
      // la mayor que deja el margen.
      bus.add([_busA(1850)]);
      await tester.pumpAndSettle();
      expect(find.text('Hasta 1,6 km'), findsOneWidget);
      expect(find.text('1,7 km'), findsNothing);
      expect(find.text('2,0 km'), findsNothing);
      expect(ruedaEn(tester), 11);

      // Se aleja otra vez: vuelve a ofrecer lo que ya no pasó, sin mover
      // la elegida.
      bus.add([_busA(2450)]);
      await tester.pumpAndSettle();
      expect(find.text('Hasta 2,2 km'), findsOneWidget);
      expect(ruedaEn(tester), 11);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 1600);
      expect(c.read(distanciaAvisoProvider), 1600);
    });

    // «Hago el cambio a 800 m y se guarda sabiendo que eso nunca va a
    // sonar» (dueño, 2026-10-07): con la ruta a 1,45 km del pin, la rueda
    // empieza en 1,5 km, al activar y al cambiar.
    testWidgets('con la ruta lejos la rueda empieza donde la ruta llega',
        (tester) async {
      final c = await montar(tester, metros: 4000, rutaKm: 1.45);
      int opciones() => (tester.widget<CupertinoPicker>(rueda).childDelegate
              as ListWheelChildListDelegate)
          .children
          .length;

      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      expect(find.text('Desde 1,5 km'), findsOneWidget);
      expect(opciones(), 16, reason: 'de 1,5 a 3 km');
      expect(ruedaEn(tester), 0, reason: 'el kilómetro no llega: 1,5 km');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 1500);

      await tester.tap(fila);
      await tester.pumpAndSettle();
      expect(find.text('Desde 1,5 km'), findsOneWidget);
      expect(opciones(), 16);
      expect(find.text('1,4 km'), findsNothing);
    });

    testWidgets('con la ruta lejos y el bus cerca dice las dos puntas',
        (tester) async {
      await montar(tester, metros: 2450, rutaKm: 1.45);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      expect(find.text('1,5 a 2,2 km'), findsOneWidget);
    });

    // La ruta a 1,45 km y el bus ya a 1,6: lo que deja el bus no la alcanza.
    // «Cambiar» lo dice en vez de abrir una rueda sin nada que sirva.
    testWidgets('«Cambiar» sin distancia que sirva lo dice sin rueda',
        (tester) async {
      final bus = StreamController<List<BusPosition>>();
      addTearDown(bus.close);
      final c = await montar(tester, rutaKm: 1.45, posiciones: bus.stream);
      bus.add([_busA(4000)]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      bus.add([_busA(1600)]);
      await tester.pumpAndSettle();
      await tester.tap(fila);
      await tester.pumpAndSettle();
      expect(rueda, findsNothing);
      expect(
          find.text('El bus A-1 ya va por lo más cerca que te pasa su ruta; '
              'no se puede cambiar la distancia'),
          findsOneWidget);
      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 1500);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    });

    testWidgets('con el bus lejos la rueda va entera y no dice tope',
        (tester) async {
      await montar(tester, metros: 4000);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hasta '), findsNothing);
      await girarA(tester, 3000);
      expect(find.text('3,0 km'), findsOneWidget);
    });

    testWidgets('sin nada guardado no bloquea lo que a 500 m todavía sirve',
        (tester) async {
      // 800 m: a 1 km ya estaría encima, pero la rueda deja elegir 500 m.
      await montar(tester, metros: 800);
      expect(find.text('Avisarme cuando esté cerca'), findsOneWidget);
    });

    // Con el bus a menos de 700 m, ni el de 500 m deja los 200 de margen:
    // sonaría en segundos.
    testWidgets('sin los 200 m de margen para el de 500 m, bloquea',
        (tester) async {
      await montar(tester, metros: 650);
      expect(find.text('El bus ya está cerca'), findsOneWidget);
    });

    testWidgets('sin nada guardado bloquea lo que ni a 500 m sirve',
        (tester) async {
      await montar(tester, metros: 450);
      expect(find.text('El bus ya está cerca'), findsOneWidget);
    });

    testWidgets('el color de la cifra cambia en la distancia del aviso',
        (tester) async {
      Color colorCifra() =>
          tester.widget<CifraViva>(find.byType(CifraViva)).style.color!;
      // 2,6 km con 2,5 km guardados: fuera del radio, verde; con 3 km
      // guardados ya está dentro, ámbar.
      final c = await montar(tester, metros: 2600, guardada: 2500);
      expect(colorCifra(), AppColors.primaryAccessible);
      await c.read(distanciaAvisoProvider.notifier).guardar(3000);
      await tester.pumpAndSettle();
      expect(colorCifra(), AppColors.warningAccessible);
    });
  });
}

double contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}
