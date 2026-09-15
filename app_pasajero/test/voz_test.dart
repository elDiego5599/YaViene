import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'realtime_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'app_drawer.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'idle_status_chip.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'location_status_chip.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'route_selector_sheet.dart';
import 'package:ya_viene_pasajero/features/onboarding/presentation/screens/'
    'onboarding_screen.dart';

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

/// ¿El doble toque de VoiceOver lo activa?
///
/// Un nodo puede anunciarse como botón y no serlo: `excludeSemantics`
/// tapa el árbol de abajo y con él la acción del gesto, así que la
/// bandera y la acción hay que mirarlas por separado.
bool seActiva(SemanticsNode nodo) =>
    nodo.getSemanticsData().hasAction(SemanticsAction.tap);

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

/// Abre el menú lateral y devuelve su contenedor.
Future<ProviderContainer> abrirMenu(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final sub = container.listen<RouteInfo?>(selectedRouteProvider, (_, __) {});
  addTearDown(sub.close);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(appBar: AppBar(), drawer: const AppDrawer()),
      ),
    ),
  );
  tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
  // Tres cuadros, y en este orden. El primero construye el menú y encola
  // el arranque de la entrada; el segundo es el primer tic de su reloj —si
  // se salta, la animación empieza a contar recién en el cuadro largo y se
  // queda a medias—; el tercero la termina. Y hasta que no termina, las
  // filas están a opacidad cero, que en Flutter también las borra del
  // árbol de semántica y no solo de la pantalla.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  return container;
}

/// Abre el selector de ruta encima de un andamio mínimo.
Future<ProviderContainer> abrirSelector(
  WidgetTester tester, {
  List<RouteInfo> rutas = const [],
}) async {
  final guia = MapGuideNotifier();
  await guia.initialize(
    hasLocation: true,
    locationSettled: true,
    hasRoute: false,
    hasSelectedBus: false,
    hasActiveAlert: false,
  );
  final container = ProviderContainer(overrides: [
    mapGuideProvider.overrideWith((ref) => guia),
    companiesProvider.overrideWith(
      (ref) async => const [Company(id: 'EMP-01', name: 'Transporte del Sur')],
    ),
    routesByCompanyProvider.overrideWith((ref, id) async => rutas),
  ]);
  addTearDown(container.dispose);
  for (final p in [selectedCompanyProvider, selectedRouteProvider]) {
    addTearDown(container.listen(p, (_, __) {}).close);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => RouteSelectorSheet.show(
                  context,
                  sheet: const RouteSelectorSheet(),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return container;
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

    testWidgets('el nombre del bus se lee igual que se ve', (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        await montarHoja(tester, desfase: 0.007645);

        expect(find.text('Bus A-1'), findsOneWidget);
        expect(find.bySemanticsLabel('Bus A-1'), findsOneWidget);
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
        expect(seActiva(nodo), isTrue);
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
        // Deshabilitado no ofrece toque: quien no puede armar el aviso
        // tampoco debería poder intentarlo desde VoiceOver.
        expect(seActiva(nodo), isFalse);
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

  group('el menú', () {
    testWidgets('cada fila se anuncia como botón', (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        await abrirMenu(tester);

        final nodo = tester.getSemantics(
          find.bySemanticsLabel('Ver guía de uso'),
        );
        expect(esBoton(nodo), isTrue);
        expect(seActiva(nodo), isTrue);
      });
    });

    testWidgets('el contador de avisos se dice con su frase', (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        final container = await abrirMenu(tester);
        container.read(activeAlertsProvider.notifier).activateAlert('A-1');
        await tester.pump();

        // En pantalla es una pastilla verde con un "1" dentro.
        expect(find.text('1'), findsOneWidget);
        expect(find.bySemanticsLabel('Avisos, 1 activo'), findsOneWidget);

        container.read(activeAlertsProvider.notifier).activateAlert('A-2');
        await tester.pump();
        expect(find.bySemanticsLabel('Avisos, 2 activos'), findsOneWidget);
      });
    });

    testWidgets('la ruta activa se dice con sus dos terminales',
        (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        final container = await abrirMenu(tester);

        expect(
          find.bySemanticsLabel('Sin ruta activa. Elige tu ruta en el mapa'),
          findsOneWidget,
        );

        container.read(selectedRouteProvider.notifier).select(
              const RouteInfo(
                id: 'R-106',
                name: 'Ruta 106',
                companyId: 'EMP-01',
                terminalA: 'Terminal',
                terminalB: 'Centro',
              ),
            );
        await tester.pump();
        expect(
          find.bySemanticsLabel('Ruta activa: Ruta 106, entre Terminal y '
              'Centro'),
          findsOneWidget,
        );
      });
    });
  });

  group('la píldora de ubicación', () {
    testWidgets('se dice de un tirón y es el botón entero', (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        final container = ProviderContainer(overrides: [
          userLocationProvider.overrideWith((ref) => _UbicacionDePrueba()),
        ]);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: marcoGolden(
              const Align(
                alignment: Alignment.topCenter,
                child: LocationStatusChip(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // El rótulo, la pista en gris y el botón son tres bloques en
        // pantalla y una sola frase en voz alta.
        final nodo = tester.getSemantics(find.bySemanticsLabel(
          'Tu punto de espera. Arrástralo para moverlo. Quitar',
        ));
        expect(esBoton(nodo), isTrue);
        expect(seActiva(nodo), isTrue);
      });
    });
  });

  group('el chip de conexión', () {
    testWidgets('se anuncia solo cuando aparece', (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        final container = ProviderContainer(overrides: [
          connectionStateProvider.overrideWith(
            (ref) => Stream.value(ConnectionStatus.disconnected),
          ),
        ]);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: marcoGolden(
              const Align(
                alignment: Alignment.topCenter,
                child: IdleStatusChip(),
              ),
            ),
          ),
        );
        // El punto del chip late en bucle: `pumpAndSettle` no vuelve
        // nunca de una animación que no termina.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final nodo =
            tester.getSemantics(find.bySemanticsLabel('Sin conexión al '
                'servidor'));
        // Nadie va a pasar el dedo buscándolo: aparece solo y tiene que
        // decirse solo.
        expect(nodo.flagsCollection.isLiveRegion, isTrue);
      });
    });

    testWidgets('los puntos de espera no se pronuncian', (tester) async {
      await conVoz(tester, () async {
        fijarPantalla(tester);
        final container = ProviderContainer(overrides: [
          connectionStateProvider.overrideWith(
            (ref) => Stream.value(ConnectionStatus.reconnecting),
          ),
        ]);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: marcoGolden(
              const Align(
                alignment: Alignment.topCenter,
                child: IdleStatusChip(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Reconectando...'), findsOneWidget);
        expect(find.bySemanticsLabel('Reconectando'), findsOneWidget);
      });
    });
  });
  group('el selector de ruta', () {
    testWidgets('cada paso dice de qué paso es, no solo su nombre',
        (tester) async {
      await conVoz(tester, () async {
        await abrirSelector(tester);

        // «Empresa» y «Ruta» sueltos son dos palabras sin frase; el
        // subtítulo va pegado porque es lo que dice qué se elige aquí.
        for (final rotulo in [
          'Empresa. Con cuál viajas',
          'Ruta. Cuál esperas',
        ]) {
          final nodo = tester.getSemantics(find.bySemanticsLabel(rotulo));
          expect(esBoton(nodo), isTrue, reason: rotulo);
          expect(seActiva(nodo), isTrue, reason: rotulo);
        }
      });
    });

    testWidgets('el aviso de la empresa se anuncia sin que lo busquen',
        (tester) async {
      await conVoz(tester, () async {
        await abrirSelector(tester);

        await tester.tap(find.text('Ruta'));
        await tester.pump();

        final nodo = tester.getSemantics(find.bySemanticsLabel(
          'Ruta. Cuál esperas. Elige primero la empresa',
        ));
        // La sacudida es un aviso que solo se ve. Sin región viva, el
        // motivo de que el toque no llevara a ninguna parte no se dice.
        expect(nodo.flagsCollection.isLiveRegion, isTrue);
      });
    });

    testWidgets('la flecha de volver dice a dónde vuelve', (tester) async {
      await conVoz(tester, () async {
        await abrirSelector(tester);

        await tester.tap(find.text('Empresa'));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Volver'), findsOneWidget);
      });
    });

    testWidgets('la insignia de la empresa no se deletrea aparte',
        (tester) async {
      await conVoz(tester, () async {
        await abrirSelector(tester);

        await tester.tap(find.text('Empresa'));
        await tester.pumpAndSettle();

        // La insignia dice «TS»: son las iniciales del nombre que va
        // justo al lado, y dichas serían el mismo dato dos veces.
        expect(find.text('TS'), findsOneWidget);
        expect(find.bySemanticsLabel('TS'), findsNothing);
        final nodo =
            tester.getSemantics(find.bySemanticsLabel('Transporte del Sur'));
        expect(esBoton(nodo), isTrue);
        expect(seActiva(nodo), isTrue);
      });
    });

    testWidgets('la ruta dice sus terminales, no la flecha', (tester) async {
      await conVoz(tester, () async {
        final container = await abrirSelector(tester, rutas: const [
          RouteInfo(
            id: 'R-106',
            name: 'Ruta 106',
            companyId: 'EMP-01',
            terminalA: 'Centro',
            terminalB: 'Norte',
          ),
        ]);
        container.read(selectedCompanyProvider.notifier).select(
              const Company(id: 'EMP-01', name: 'Transporte del Sur'),
            );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ruta'));
        await tester.pumpAndSettle();

        // En pantalla es «Centro ↔ Norte»; leído, la flecha se pronuncia
        // y deja dos nombres sueltos sin relación entre ellos.
        expect(find.text('Centro ↔ Norte'), findsOneWidget);
        final nodo = tester.getSemantics(
          find.bySemanticsLabel('Ruta 106, entre Centro y Norte'),
        );
        expect(esBoton(nodo), isTrue);
        expect(seActiva(nodo), isTrue);
      });
    });
  });

  group('la entrada', () {
    testWidgets('cada razón se oye entera, no en dos mitades', (tester) async {
      SharedPreferences.setMockInitialValues({});
      fijarPantalla(tester);
      await tester.pumpWidget(
        ProviderScope(child: marcoGoldenRuteado(const OnboardingScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      final manija = tester.ensureSemantics();

      // Promesa y letra chica se anuncian juntas: sueltas, la segunda
      // llega sin saber de qué habla.
      expect(
        find.bySemanticsLabel(
          'Buses en vivo. Ves dónde va el tuyo, no dónde debería ir',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Aviso antes de que llegue. Suena cuando se acerca a tu punto '
          'de espera',
        ),
        findsOneWidget,
      );

      manija.dispose();
    });
  });
}
