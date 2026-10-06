// La hoja con la distancia del aviso elegida por la persona (dueño,
// 2026-10-06): el primer aviso pregunta con la rueda; después, una fila
// «Te avisamos a … · Cambiar» bajo el botón deja cambiarla (en iPhone, con
// el aviso activo, va en la nota de encima), y cambiarla también mueve el
// aviso que está sonando por ese bus.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/aviso.dart';
import 'package:ya_viene_pasajero/core/widgets/cifra_viva.dart';
import 'package:ya_viene_pasajero/core/widgets/dialogo.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/alert_toggle_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';
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
  }) async {
    SharedPreferences.setMockInitialValues(
      {if (guardada != null) 'distancia_aviso_m': guardada},
    );
    // Un iPhone 13: la ventana de la rueda cabe entera con sus dos botones.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider
          .overrideWith((ref, routeId) => Stream.value([_busA(metros)])),
      // El recorrido pasa por el pin: aquí no se prueba la ruta lejana.
      routeTrajectoryProvider.overrideWith(
        (ref, routeId) => RouteTrajectory(
          routeId: routeId,
          routeName: 'Ruta 1',
          points: const [
            GeoPoint(lat: _lat, lon: _lon - 0.05),
            GeoPoint(lat: _lat, lon: _lon + 0.05),
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
          home: const Scaffold(body: EtaBottomSheet()),
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

    testWidgets('cerrar la rueda sin elegir no arma nada ni dice nada',
        (tester) async {
      final c = await montar(tester);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.byType(Dialogo), findsNothing);
      expect(find.byType(AvisoTarjeta), findsNothing);
      expect(c.read(activeAlertsProvider), isEmpty);
      expect(find.text('Avisarme cuando esté cerca'), findsOneWidget);
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
    testWidgets('con una distancia guardada la fila la dice y la cambia',
        (tester) async {
      final c = await montar(tester, guardada: 2000);
      expect(find.text('Te avisamos a 2,0 km'), findsOneWidget);

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      expect(find.text('Distancia del aviso'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(ruedaEn(tester), 15, reason: 'abre en la distancia de ahora');

      await girarA(tester, 1200);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(c.read(distanciaAvisoProvider), 1200);
      expect(find.text('Te avisamos a 1,2 km'), findsOneWidget);
      expect(c.read(activeAlertsProvider), isEmpty,
          reason: 'cambiar la distancia no arma ningún aviso');
    });

    testWidgets('«Cancelar» deja la distancia como estaba', (tester) async {
      final c = await montar(tester, guardada: 2000);
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      await girarA(tester, 700);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(c.read(distanciaAvisoProvider), 2000);
      expect(find.text('Te avisamos a 2,0 km'), findsOneWidget);
    });

    testWidgets('con el aviso activo también cambia el aviso', (tester) async {
      final c = await montar(tester, guardada: 1800);
      await tester.tap(find.text('Avisarme cuando esté cerca'));
      await tester.pumpAndSettle();
      expect(c.read(proximityAlertsProvider.notifier).radioDe('A-1'), 1800);

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Te avisamos cuando el bus esté así de cerca. También '
            'cambia el aviso que tienes activo.'),
        findsOneWidget,
      );
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

    testWidgets('los textos de la fila contrastan con la hoja (WCAG AA)',
        (tester) async {
      await montar(tester, guardada: 1500);
      for (final texto in ['Te avisamos a 1,5 km', 'Cambiar']) {
        final color = tester.widget<Text>(find.text(texto)).style!.color!;
        expect(contraste(color, AppColors.arena), greaterThanOrEqualTo(4.5),
            reason: texto);
      }
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
      SharedPreferences.setMockInitialValues({'distancia_aviso_m': 1500});
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
      await tester.pumpAndSettle();

      expect(find.text('Bus sin señal'), findsOneWidget);
      expect(find.text('Te avisamos a 1,5 km'), findsOneWidget);
    });
  });

  group('la hoja mide con la distancia elegida', () {
    testWidgets('el bus ya está cerca según la distancia guardada',
        (tester) async {
      // 1600 m: con 2 km guardados ya está dentro; el kilómetro de antes lo
      // habría dejado armar.
      await montar(tester, metros: 1600, guardada: 2000);
      expect(find.text('El bus ya está cerca'), findsOneWidget);
    });

    testWidgets('sin nada guardado no bloquea lo que a 500 m todavía sirve',
        (tester) async {
      // 800 m: a 1 km ya estaría encima, pero la rueda deja elegir 500 m.
      await montar(tester, metros: 800);
      expect(find.text('Avisarme cuando esté cerca'), findsOneWidget);
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
