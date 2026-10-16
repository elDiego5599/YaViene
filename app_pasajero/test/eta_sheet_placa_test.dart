import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';

/// La tarjeta del bus con el diseño que eligió el dueño (2026-09-30, «A»):
/// «BUS» y la placa blanca encabezan, un filo la separa de la distancia,
/// y lo que haya que explicar va en una nota con su ícono, no en un
/// párrafo gris. La franja de color de arriba se fue: el número ya lleva
/// la urgencia en su color.
class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

void main() {
  SharedPreferences.setMockInitialValues({});
  const userLat = 6.2442;
  const userLon = -75.5812;

  Future<ProviderContainer> montar(WidgetTester tester,
      {required bool rutaCerca}) async {
    // Lejos: el recorrido corre a ~11 km al norte del punto, así que el
    // aviso no sonaría nunca y la hoja tiene que decirlo.
    final latRuta = rutaCerca ? userLat : userLat + 0.1;
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([
          BusPosition(
            busId: 'A-1',
            routeId: 'R1',
            lat: userLat + 0.02,
            lon: userLon,
            heading: 0,
            speedKmh: 30,
            timestamp: DateTime.now(),
            isGhostBus: false,
          ),
        ]),
      ),
      routeTrajectoryProvider.overrideWith(
        (ref, routeId) => RouteTrajectory(
          routeId: routeId,
          routeName: 'Ruta 1',
          points: [
            GeoPoint(lat: latRuta, lon: userLon - 0.05),
            GeoPoint(lat: latRuta, lon: userLon + 0.05),
          ],
        ),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: EtaBottomSheet())),
      ),
    );
    await tester.pump();
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: userLat,
        lon: userLon,
      ),
    );
    container
        .read(selectedRouteProvider.notifier)
        .select(const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'));
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  testWidgets('la placa va en blanco, con letra negra y filo oscuro',
      (tester) async {
    await montar(tester, rutaCerca: true);

    expect(find.text('BUS'), findsOneWidget);
    final placa = find.byKey(const ValueKey('hoja-placa'));
    expect(placa, findsOneWidget);
    expect(
      find.descendant(of: placa, matching: find.text('A-1')),
      findsOneWidget,
    );
    final caja = tester.widget<Container>(placa).decoration! as BoxDecoration;
    expect(caja.color, AppColors.placa);
    expect(caja.color, const Color(0xFFFFFFFF));
    expect((caja.border! as Border).top.color, AppColors.textPrimary);
    final letra = tester.widget<Text>(
      find.descendant(of: placa, matching: find.text('A-1')),
    );
    expect(letra.style!.color, AppColors.textPrimary);
  });

  testWidgets('«BUS» y la placa se leen juntos: «Bus A-1»', (tester) async {
    final voz = tester.ensureSemantics();
    await montar(tester, rutaCerca: true);

    expect(find.bySemanticsLabel('Bus A-1'), findsOneWidget);
    expect(find.bySemanticsLabel('BUS'), findsNothing);
    voz.dispose();
  });

  testWidgets('un filo separa el encabezado de la distancia, sin franja',
      (tester) async {
    await montar(tester, rutaCerca: true);

    final filo = tester.widget<Container>(
      find.byKey(const ValueKey('hoja-filo')),
    );
    expect(filo.color, AppColors.hairline);
    expect(filo.constraints, const BoxConstraints.tightFor(height: 1));
    // La franja de 4 que coronaba la tarjeta ya no existe.
    expect(
      find.byWidgetPredicate((w) =>
          w is AnimatedContainer &&
          w.constraints == const BoxConstraints.tightFor(height: 4)),
      findsNothing,
    );
    // El encabezado queda encima del filo y el número debajo.
    final yPlaca =
        tester.getRect(find.byKey(const ValueKey('hoja-placa'))).bottom;
    final yFilo = tester.getRect(find.byKey(const ValueKey('hoja-filo'))).top;
    final yNumero = tester.getRect(find.text('2,2')).top;
    expect(yPlaca, lessThan(yFilo));
    expect(yFilo, lessThan(yNumero));
  });

  testWidgets('la placa y la distancia van juntas en una tarjeta con marco',
      (tester) async {
    await montar(tester, rutaCerca: false);

    // Prueba del dueño (2026-09-30): quién es y cuánto falta, enmarcados
    // como las tarjetas del selector; la nota y el botón quedan fuera.
    final tarjeta = find.byKey(const ValueKey('hoja-tarjeta'));
    expect(tarjeta, findsOneWidget);
    for (final dentro in [
      find.byKey(const ValueKey('hoja-placa')),
      find.byKey(const ValueKey('hoja-filo')),
      find.text('2,2'),
      find.text('km de ti'),
    ]) {
      expect(find.descendant(of: tarjeta, matching: dentro), findsOneWidget);
    }
    for (final fuera in [
      find.byKey(const ValueKey('hoja-nota')),
      find.text('Esta ruta no pasa cerca'),
    ]) {
      expect(fuera, findsOneWidget);
      expect(find.descendant(of: tarjeta, matching: fuera), findsNothing);
    }

    final caja = tester.widget<Container>(tarjeta).decoration! as BoxDecoration;
    expect(caja.color, AppColors.surface);
    expect((caja.border! as Border).top.color, AppColors.hairline);
    expect(caja.borderRadius, BorderRadius.circular(AppRadius.card));
    // Blanca sobre la hoja blanca (dueño, 2026-10-16): la despega su sombra.
    expect(caja.boxShadow, isNotEmpty);
    // El filo cruza la tarjeta de marco a marco.
    expect(
      tester.getSize(find.byKey(const ValueKey('hoja-filo'))).width,
      tester.getSize(tarjeta).width - 2,
    );
  });

  testWidgets('ruta lejos: una nota corta con ícono coral, sin el párrafo',
      (tester) async {
    await montar(tester, rutaCerca: false);

    const nueva = 'La ruta no pasa cerca de tu punto. Muévelo o elige otra '
        'ruta.';
    expect(find.text(nueva), findsOneWidget);
    expect(find.textContaining('el aviso no sonaría'), findsNothing);
    expect(find.textContaining('El recorrido de esta ruta'), findsNothing);

    final nota = find.byKey(const ValueKey('hoja-nota'));
    expect(
        find.descendant(of: nota, matching: find.text(nueva)), findsOneWidget);
    final icono = tester.widget<Icon>(
      find.descendant(of: nota, matching: find.byType(Icon)),
    );
    expect(icono.icon, Icons.wrong_location_outlined);
    expect(icono.color, AppColors.coralAccessible);
    // Blanca sobre la hoja blanca: se despega con su sombra.
    expect(
        (tester.widget<Container>(nota).decoration! as BoxDecoration).boxShadow,
        isNotEmpty);
    // El botón sigue diciendo lo suyo, igual que antes.
    expect(find.text('Esta ruta no pasa cerca'), findsOneWidget);
  });

  testWidgets('con la ruta cerca y el bus a la vista no hay nota',
      (tester) async {
    await montar(tester, rutaCerca: true);

    expect(find.byKey(const ValueKey('hoja-nota')), findsNothing);
  });

  testWidgets('la nota se va sin salto al llevar el pin a la ruta',
      (tester) async {
    final container = await montar(tester, rutaCerca: false);
    await tester.pumpAndSettle();
    final nota = find.byKey(const ValueKey('hoja-nota'));
    expect(nota, findsOneWidget);
    final boton = find.text('Esta ruta no pasa cerca');
    final antes = tester.getRect(boton).center.dy;

    // El pin cae sobre el recorrido (que corre ~11 km al norte).
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: userLat + 0.1,
        lon: userLon,
      ),
    );
    await tester.pump();
    // 60 de los 360 del cambio: la nota se apaga en el primer 40 %.
    await tester.pump(const Duration(milliseconds: 60));

    // A mitad del cambio el botón va de camino, no teletransportado, y la
    // nota todavía se está apagando.
    final botonNuevo = find.text('Avisarme cuando esté cerca');
    final medio = tester.getRect(botonNuevo).center.dy;
    expect(nota, findsOneWidget);
    final opacidad = tester
        .widgetList<FadeTransition>(
            find.ancestor(of: nota, matching: find.byType(FadeTransition)))
        .map((f) => f.opacity.value)
        .reduce((a, b) => a * b);
    expect(opacidad, inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(nota, findsNothing);
    final despues = tester.getRect(botonNuevo).center.dy;
    expect(despues, lessThan(antes));
    expect(medio, inExclusiveRange(despues, antes));
  });
}
