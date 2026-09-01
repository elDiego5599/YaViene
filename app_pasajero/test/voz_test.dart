import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'eta_bottom_sheet.dart';

import 'golden/golden_harness.dart';

/// Lo que la app dice en voz alta.
///
/// Un árbol de widgets puede verse perfecto y no decir nada: dos textos
/// sueltos donde hay una frase, un botón que se anuncia como texto, un
/// asa de 4 px que no se anuncia. Estas pruebas leen el árbol de
/// semántica —lo mismo que lee VoiceOver— y no el de pintura.
const double _lat = 6.2442;
const double _lon = -75.5812;

class _UbicacionDePrueba extends UserLocationNotifier {
  _UbicacionDePrueba() {
    state = const UserLocationState(
      mode: UserLocationMode.manual,
      lat: _lat,
      lon: _lon,
    );
  }
}

BusPosition _bus(double desfase) => BusPosition(
      busId: 'A-1',
      routeId: 'R1',
      lat: _lat + desfase,
      lon: _lon,
      heading: 0,
      speedKmh: 30,
      timestamp: DateTime.now(),
      isGhostBus: false,
    );

/// Monta la hoja del bus con un bus a la distancia que se le pida.
Future<void> montarHoja(WidgetTester tester, {required double desfase}) async {
  final container = ProviderContainer(overrides: [
    userLocationProvider.overrideWith((ref) => _UbicacionDePrueba()),
    busPositionsSourceProvider.overrideWith(
      (ref, routeId) => Stream.value([_bus(desfase)]),
    ),
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
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: marcoGolden(
        const Align(alignment: Alignment.bottomCenter, child: EtaBottomSheet()),
      ),
    ),
  );
  await tester.pump();
  container.read(selectedRouteProvider.notifier).select(
        const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
      );
  container.read(selectedBusesProvider.notifier).toggleBus('A-1');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// ¿Este nodo se anuncia como botón?
///
/// `hasFlag` quedó obsoleto: las banderas ahora viajan juntas en
/// `flagsCollection`, y las que admiten "no dice nada" —como la de
/// habilitado— son de tres estados, no de dos.
bool esBoton(SemanticsNode nodo) => nodo.flagsCollection.isButton;

/// ¿Se anuncia habilitado (`true`), deshabilitado (`false`), o no dice
/// nada al respecto (`null`)?
bool? seHabilita(SemanticsNode nodo) =>
    switch (nodo.flagsCollection.isEnabled) {
      Tristate.isTrue => true,
      Tristate.isFalse => false,
      Tristate.none => null,
    };

/// Enciende el árbol de semántica mientras dure el cuerpo.
///
/// Flutter solo lo construye si alguien lo pide —VoiceOver en el
/// teléfono, esto en las pruebas— y exige apagarlo antes de que el test
/// termine, así que no vale dejarlo en un `addTearDown`.
Future<void> conVoz(WidgetTester tester, Future<void> Function() cuerpo) async {
  final voz = tester.ensureSemantics();
  try {
    await cuerpo();
  } finally {
    voz.dispose();
  }
}

/// Monta la hoja con ruta elegida pero sin bus: el estado que sí se pliega.
Future<void> montarHojaVacia(WidgetTester tester) async {
  final container = ProviderContainer(overrides: [
    userLocationProvider.overrideWith((ref) => _UbicacionDePrueba()),
    busPositionsSourceProvider.overrideWith(
      (ref, routeId) => Stream.value(const <BusPosition>[]),
    ),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: marcoGolden(
        const Align(alignment: Alignment.bottomCenter, child: EtaBottomSheet()),
      ),
    ),
  );
  await tester.pump();
  container.read(selectedRouteProvider.notifier).select(
        const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
      );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('la hoja del bus', () {
    testWidgets('dice la distancia entera, no el número suelto',
        (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        await montarHoja(tester, desfase: 0.007645);

        // En pantalla son dos bloques: "850" en 64 y "m de ti" en 15.
        expect(find.text('850'), findsOneWidget);
        expect(find.bySemanticsLabel('A 850 metros de ti'), findsOneWidget);
        // Y el número suelto ya no es un nodo propio que leer aparte.
        expect(find.bySemanticsLabel('850'), findsNothing);
      });
    });

    testWidgets('los kilómetros llevan coma y unidad en palabras',
        (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        await montarHoja(tester, desfase: 0.0135);

        expect(find.bySemanticsLabel(RegExp(r'^A 1,5 kilómetros de ti$')),
            findsOneWidget);
      });
    });

    testWidgets('el nombre del bus dice qué es cada parte', (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        await montarHoja(tester, desfase: 0.007645);

        expect(find.text('Ruta 1 - A-1'), findsOneWidget);
        expect(find.bySemanticsLabel('Ruta 1, bus A-1'), findsOneWidget);
      });
    });

    testWidgets('el botón de aviso se anuncia como botón', (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        await montarHoja(tester, desfase: 0.0135);

        final nodo = tester.getSemantics(
          find.bySemanticsLabel('Avisarme cuando esté cerca'),
        );
        expect(esBoton(nodo), isTrue);
        expect(seHabilita(nodo), isTrue);
      });
    });

    testWidgets('bloqueado, el botón se anuncia deshabilitado', (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        // Dentro del radio de aviso: el botón queda bloqueado y su rótulo
        // pasa a decir por qué.
        await montarHoja(tester, desfase: 0.002);

        final nodo =
            tester.getSemantics(find.bySemanticsLabel('El bus ya está cerca'));
        expect(esBoton(nodo), isTrue);
        expect(seHabilita(nodo), isFalse);
      });
    });

    testWidgets('con un bus elegido, el asa no promete un plegado que no hay',
        (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        await montarHoja(tester, desfase: 0.007645);

        // La tarjeta del bus es la única que no se pliega. El asa sigue
        // dibujada, pero anunciarla como botón sería mentir.
        expect(find.bySemanticsLabel('Plegar la tarjeta'), findsNothing);
        expect(
          esBoton(tester.getSemantics(find.byKey(const ValueKey(
            'sheet-handle',
          )))),
          isFalse,
        );
      });
    });

    testWidgets('sin bus elegido, el asa dice si abre o pliega',
        (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        await montarHojaVacia(tester);

        final asa = find.bySemanticsLabel('Plegar la tarjeta');
        expect(asa, findsOneWidget);
        expect(esBoton(tester.getSemantics(asa)), isTrue);

        await tester.tap(find.byKey(const ValueKey('sheet-handle')));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Abrir la tarjeta'), findsOneWidget);
      });
    });
  });
}
