import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_guide_copy.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/location_status_chip.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_tour_overlay.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/search_pill_bar.dart';

/// T6.5 · Los rótulos de la interfaz viven en dos sitios: aquí y en la
/// landing (`YaVieneWeb`), que los repite en los pasos de «Tres pasos»,
/// en el selector del mockup y en el simulador del teléfono. Nadie los
/// mira juntos: un día la app dice «Elige tu empresa» y la página sigue
/// con «Elige empresa» meses, porque ninguna prueba cruza los dos repos.
///
/// Los documentos legales ya se ataron así —`test/legal_*` aquí,
/// `tests/coherencia.test.ts` allá—, con la misma lista afirmada en los
/// dos lados. Esto hace lo mismo con la interfaz.
///
/// Cada frase se busca PINTADA, con `find.text` sobre el widget montado en
/// el estado que la muestra. La versión anterior leía el código fuente con
/// `contains`, y la auditoría del 2026-09-27 (R-04) vio el porqué no basta:
/// cambiar «Ruta activa» por «Ruta en curso» en pantalla seguía en verde
/// mientras la frase sobreviviera en un comentario o en otra rama.
///
/// El listado espejo vive en `YaVieneWeb/tests/coherencia-textos.test.ts`:
/// si cambia una frase, se cambia en los dos lados del código y en las dos
/// pruebas. Ninguna CI trae el otro repo, así que cada lado se vigila solo
/// y la lista compartida es el eslabón.
void main() {
  /// frase → escenas de la app donde se ve pintada (todas).
  const frases = <String, List<String>>{
    '¿Qué bus esperas?': ['barra sin ruta'],
    'Toca para buscar tu ruta': ['barra sin ruta'],
    'Ruta activa': ['barra con ruta'],
    'Elige tu ruta': ['selector al abrir'],
    'Dos pasos y ves los buses moviéndose.': ['selector al abrir'],
    'Con cuál viajas': ['selector al abrir'],
    'Cuál esperas': ['selector al abrir'],
    'Elegir empresa': ['selector al abrir'],
    'Elige empresa': ['selector lista de empresas'],
    'Empresa de transporte masivo': ['selector con empresa'],
    'Elige ruta': ['selector lista de rutas'],
    'Ver buses en vivo': ['selector con ruta'],
    'Toca el mapa para indicar dónde estás': ['hoja sin punto'],
    'Ahí ponemos tu punto de espera y medimos desde él': ['hoja sin punto'],
    'Avisarme cuando esté cerca': ['hoja con bus'],
    'Aviso activado': ['hoja con aviso', 'hoja sin señal con aviso'],
    'Puedes cambiar de aplicación; no cierres Ya Viene del todo': [
      'hoja con aviso',
    ],
    'Localizando tu ubicación…': ['píldora localizando'],
    'Arrástralo para moverlo': ['píldora con pin'],
    'Fija tu punto de espera': ['guía sin ubicación'],
    'Tu ciudad en tiempo real.': ['portada'],
  };

  /// Afirma que todas las frases de [escena] están en pantalla ahora.
  void pintadas(String escena) {
    final deEscena = [
      for (final e in frases.entries)
        if (e.value.contains(escena)) e.key,
    ];
    expect(deEscena, isNotEmpty, reason: 'escena sin frases: $escena');
    for (final frase in deEscena) {
      expect(
        find.text(frase, findRichText: true),
        findsWidgets,
        reason: '«$frase» ya no se pinta en «$escena». La web la repite '
            '(YaVieneWeb/tests/coherencia-textos.test.ts): si cambia aquí, '
            'cambia allá.',
      );
    }
  }

  final vistas = <String>{};
  void vista(String escena) {
    pintadas(escena);
    vistas.add(escena);
  }

  const ruta = RouteInfo(id: 'R-106', name: 'Ruta 106', companyId: 'EMP-01');
  const empresa = Company(id: 'EMP-01', name: 'Sobusa');

  group('barra de búsqueda', () {
    Future<ProviderContainer> montar(WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(selectedRouteProvider, (_, __) {});
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SearchPillBar(),
              ),
            ),
          ),
        ),
      );
      return container;
    }

    testWidgets('sin ruta', (tester) async {
      await montar(tester);
      vista('barra sin ruta');
    });

    testWidgets('con ruta', (tester) async {
      final container = await montar(tester);
      container.read(selectedRouteProvider.notifier).select(ruta);
      await tester.pumpAndSettle();
      vista('barra con ruta');
    });
  });

  testWidgets('selector de ruta, paso a paso', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // La guía saltada: así lo pintado es la hoja y no la tarjeta de la guía.
    final guia = MapGuideNotifier();
    await guia.initialize(
      hasLocation: true,
      locationSettled: true,
      hasRoute: false,
      hasSelectedBus: false,
      hasActiveAlert: false,
    );
    await guia.empezar();
    await guia.skip();
    final container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guia),
      companiesProvider.overrideWith((ref) async => const [empresa]),
      routesByCompanyProvider.overrideWith((ref, id) async => const [ruta]),
    ]);
    addTearDown(container.dispose);
    container.listen(selectedCompanyProvider, (_, __) {});
    container.listen(selectedRouteProvider, (_, __) {});

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
    vista('selector al abrir');

    await tester.tap(find.text('Elegir empresa'));
    await tester.pumpAndSettle();
    vista('selector lista de empresas');

    await tester.tap(find.text('Sobusa'));
    await tester.pumpAndSettle();
    expect(container.read(selectedCompanyProvider), empresa);
    vista('selector con empresa');

    await tester.tap(find.text('Elegir ruta'));
    await tester.pumpAndSettle();
    vista('selector lista de rutas');

    await tester.tap(find.text('Ruta 106'));
    await tester.pumpAndSettle();
    expect(container.read(selectedRouteProvider), ruta);
    vista('selector con ruta');
  });

  group('hoja de distancia', () {
    late ProviderContainer container;
    late List<BusPosition> posiciones;

    setUp(() {
      posiciones = [];
      container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _Ubicacion()),
        busPositionsSourceProvider.overrideWith(
          (ref, routeId) => Stream.value(posiciones),
        ),
      ]);
      container.listen(selectedRouteProvider, (_, __) {});
      addTearDown(container.dispose);
    });

    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: EtaBottomSheet())),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Punto de espera fijado, ruta elegida y un bus a ~1,1 km; con señal
    /// salvo que [sinSenal] lo vuelva fantasma de hace dos minutos.
    void conBusElegido({bool sinSenal = false}) {
      posiciones = [
        BusPosition(
          busId: 'A-1',
          routeId: ruta.id,
          lat: 11.0100,
          lon: -74.8070,
          heading: 0,
          speedKmh: 30,
          timestamp:
              DateTime.now().subtract(Duration(minutes: sinSenal ? 2 : 0)),
          isGhostBus: sinSenal,
        ),
      ];
      (container.read(userLocationProvider.notifier) as _Ubicacion).set(
        const UserLocationState(
          mode: UserLocationMode.manual,
          lat: 11.0000,
          lon: -74.8070,
        ),
      );
      container.read(selectedRouteProvider.notifier).select(ruta);
      container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    }

    testWidgets('sin punto de espera', (tester) async {
      await montar(tester);
      vista('hoja sin punto');
    });

    testWidgets('con un bus elegido', (tester) async {
      conBusElegido();
      await montar(tester);
      vista('hoja con bus');
    });

    testWidgets('con el aviso puesto', (tester) async {
      conBusElegido();
      container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
      await montar(tester);
      vista('hoja con aviso');
    });

    testWidgets('con el aviso puesto y el bus sin señal', (tester) async {
      conBusElegido(sinSenal: true);
      container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
      await montar(tester);
      vista('hoja sin señal con aviso');
    });
  });

  group('píldora de ubicación', () {
    Future<void> montar(WidgetTester tester, UserLocationState estado) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _Ubicacion()..set(estado)),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Center(child: LocationStatusChip())),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('localizando', (tester) async {
      await montar(
        tester,
        const UserLocationState(mode: UserLocationMode.locating),
      );
      vista('píldora localizando');
    });

    testWidgets('con el pin puesto a mano', (tester) async {
      await montar(
        tester,
        const UserLocationState(
          mode: UserLocationMode.manual,
          lat: 10.99,
          lon: -74.79,
        ),
      );
      vista('píldora con pin');
    });
  });

  testWidgets('guía, primer paso sin ubicación', (tester) async {
    // La guía del mapa pinta la copia de su paso en `MapGuideOverlay`
    // (`map_screen.dart`); aquí se monta ese mismo par sin el mapa.
    final copia = mapGuideCopy(MapGuideStep.location);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MapGuideOverlay(
                target: const Rect.fromLTWH(160, 260, 100, 64),
                title: copia.title,
                message: copia.message,
                icon: copia.icon,
                stepIndex: 0,
                stepCount: MapGuideStep.values.length,
                onSkip: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    vista('guía sin ubicación');
  });

  testWidgets('portada', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: InkHero()))),
    );
    await tester.pumpAndSettle();
    vista('portada');
  });

  // Va al final: `flutter test` corre en orden de declaración. Si una
  // escena nueva entra en la lista sin su prueba, esto lo dice.
  test('cada escena de la lista se montó', () {
    expect(vistas, {for (final escenas in frases.values) ...escenas});
  });
}

class _Ubicacion extends UserLocationNotifier {
  void set(UserLocationState estado) => state = estado;
}
