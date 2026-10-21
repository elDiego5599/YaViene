import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/selected_buses_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/location_status_chip.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_tour_overlay.dart';

import 'helpers/contraste.dart';
import 'helpers/mapa.dart';

class _FakeLocation extends StateNotifier<UserLocationState>
    implements UserLocationNotifier {
  _FakeLocation([
    super.state = const UserLocationState(
      mode: UserLocationMode.gps,
      lat: 11.0041,
      lon: -74.8070,
    ),
  ]);

  bool fixedPin = false;
  bool cleared = false;
  bool gpsAsked = false;

  @override
  void setManualPin(double lat, double lon) {
    fixedPin = true;
  }

  @override
  Future<void> clearManualPin() async {
    cleared = true;
  }

  @override
  Future<void> useGps() async {
    gpsAsked = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MapGuideNotifier', () {
    test('inicia en ubicación sin GPS y en búsqueda con GPS listo', () async {
      final withoutLocation = MapGuideNotifier();
      addTearDown(withoutLocation.dispose);
      await withoutLocation.initialize(
        hasLocation: false,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      await withoutLocation.empezar();
      expect(withoutLocation.state.step, MapGuideStep.location);

      SharedPreferences.setMockInitialValues({});
      final withLocation = MapGuideNotifier();
      addTearDown(withLocation.dispose);
      await withLocation.initialize(
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      await withLocation.empezar();
      expect(withLocation.state.step, MapGuideStep.search);
    });

    // La primera vez la app saluda y pregunta antes de meterse en la guía
    // (dueño, 2026-10-02: «nunca se recibe al usuario»). Mientras no se
    // escoja no hay paso ni nada guardado: cerrar la app con la bienvenida
    // abierta la vuelve a mostrar.
    test('la primera vez da la bienvenida y no arranca la guía sola', () async {
      final guide = MapGuideNotifier();
      addTearDown(guide.dispose);
      await guide.initialize(
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      expect(guide.state.bienvenida, isTrue);
      expect(guide.state.step, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('map_guide_step'), isFalse);
      expect(prefs.containsKey('map_guide_status'), isFalse);

      final otraVez = MapGuideNotifier();
      addTearDown(otraVez.dispose);
      await otraVez.initialize(
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      expect(otraVez.state.bienvenida, isTrue);
    });

    test('«Ver la guía» la arranca donde toca', () async {
      final sinUbicacion = MapGuideNotifier();
      addTearDown(sinUbicacion.dispose);
      await sinUbicacion.initialize(
        hasLocation: false,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      await sinUbicacion.empezar();
      expect(sinUbicacion.state.bienvenida, isFalse);
      expect(sinUbicacion.state.step, MapGuideStep.location);
      expect(sinUbicacion.state.includesLocation, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('map_guide_step'), MapGuideStep.location.index);
    });

    test('«Ir a la app» no vuelve a dar la bienvenida', () async {
      final guide = MapGuideNotifier();
      addTearDown(guide.dispose);
      await guide.initialize(
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      await guide.skip();
      expect(guide.state.bienvenida, isFalse);

      final despues = MapGuideNotifier();
      addTearDown(despues.dispose);
      await despues.initialize(
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      expect(despues.state.bienvenida, isFalse);
      expect(despues.state.skipped, isTrue);
      expect(despues.state.step, isNull);
    });

    test('solo avanza cuando se completa el paso actualmente visible',
        () async {
      final guide = MapGuideNotifier();
      addTearDown(guide.dispose);
      await guide.initialize(
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      await guide.empezar();

      await guide.complete(MapGuideStep.company);
      expect(guide.state.step, MapGuideStep.search);

      await guide.complete(MapGuideStep.search);
      expect(guide.state.step, MapGuideStep.company);

      await guide.complete(MapGuideStep.company);
      expect(guide.state.step, MapGuideStep.route);
      await guide.complete(MapGuideStep.route);
      expect(guide.state.step, MapGuideStep.launchBuses);
    });

    test('una guía a medias no se reanuda sola al volver a entrar', () async {
      SharedPreferences.setMockInitialValues({
        'map_tour_seen': true,
        'map_tour_bus_seen': true,
      });
      final guide = MapGuideNotifier();
      addTearDown(guide.dispose);
      await guide.initialize(
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      await guide.empezar();
      expect(guide.state.step, MapGuideStep.search);

      await guide.complete(MapGuideStep.search);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('map_guide_step'), MapGuideStep.company.index);

      // El usuario salió de la app con la guía a medias: al volver, la guía
      // NO salta; la repite desde el drawer cuando quiera.
      final resumed = MapGuideNotifier();
      addTearDown(resumed.dispose);
      await resumed.initialize(
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      expect(resumed.state.initialized, isTrue);
      expect(resumed.state.step, isNull);
    });

    // Sin cuentas (D3) la guía es del teléfono. Las dos claves que la
    // ataban a una cuenta guardaban el id de quien entró: se borran al
    // arrancar, y lo que el teléfono ya había hecho con la guía se respeta.
    test('las claves de la cuenta se borran y una guía terminada no vuelve',
        () async {
      SharedPreferences.setMockInitialValues({
        'map_guide_user': 'uid-viejo',
        'map_guide_eligible': true,
        'map_guide_version': 2,
        'map_guide_status': 'completed',
      });
      final guide = MapGuideNotifier();
      addTearDown(guide.dispose);
      await guide.initialize(
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      expect(guide.state.initialized, isTrue);
      expect(guide.state.step, isNull);
      expect(guide.state.completed, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('map_guide_user'), isFalse);
      expect(prefs.containsKey('map_guide_eligible'), isFalse);
    });

    test('saltar persiste y reiniciar vuelve al inicio apropiado', () async {
      final guide = MapGuideNotifier();
      addTearDown(guide.dispose);
      await guide.initialize(
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      await guide.skip();
      expect(guide.state.skipped, isTrue);
      expect(guide.state.step, isNull);

      await guide.restart(
        hasLocation: false,
        locationSettled: true,
      );
      expect(guide.state.step, MapGuideStep.location);
    });
  });

  group('MapGuideOverlay', () {
    Future<void> pumpGuide(
      WidgetTester tester, {
      required VoidCallback onSkip,
      required ValueChanged<bool> onTargetTap,
      String? primaryLabel,
      VoidCallback? onPrimary,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () => onTargetTap(true),
                  child: const ColoredBox(
                    color: Color(0xFFF8FAFC),
                    child: SizedBox.expand(),
                  ),
                ),
                MapGuideOverlay(
                  target: const Rect.fromLTWH(160, 260, 100, 64),
                  title: 'Empieza aquí',
                  message: 'Toca la zona iluminada para continuar.',
                  icon: Icons.search_outlined,
                  stepIndex: 1,
                  stepCount: 8,
                  primaryLabel: primaryLabel,
                  onPrimary: onPrimary,
                  onSkip: onSkip,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
    }

    Future<void> pumpEntrada(
      WidgetTester tester, {
      required bool sinAnimaciones,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(disableAnimations: sinAnimaciones),
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  const ColoredBox(
                    color: Color(0xFFF8FAFC),
                    child: SizedBox.expand(),
                  ),
                  MapGuideOverlay(
                    target: const Rect.fromLTWH(160, 260, 100, 64),
                    title: 'Empieza aquí',
                    message: 'Toca la zona iluminada para continuar.',
                    icon: Icons.search_outlined,
                    stepIndex: 1,
                    stepCount: 8,
                    onSkip: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    double escalaDeLaTarjeta(WidgetTester tester) {
      final escala = tester.widget<ScaleTransition>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('guide_card')),
              matching: find.byType(ScaleTransition),
            )
            .first,
      );
      return escala.scale.value;
    }

    testWidgets('la tarjeta entra creciendo y termina en su tamaño',
        (tester) async {
      await pumpEntrada(tester, sinAnimaciones: false);
      await tester.pump();
      expect(escalaDeLaTarjeta(tester), lessThan(1.0));

      await tester.pump(const Duration(milliseconds: 450));
      expect(escalaDeLaTarjeta(tester), 1.0);
    });

    testWidgets('con movimiento reducido la tarjeta no crece ni se pasa',
        (tester) async {
      await pumpEntrada(tester, sinAnimaciones: true);
      await tester.pump();
      // Crecer es movimiento, y eso es lo que apaga «Reducir movimiento».
      // La tarjeta se funde, quieta.
      expect(escalaDeLaTarjeta(tester), 1.0);

      await tester.pump(const Duration(milliseconds: 120));
      expect(escalaDeLaTarjeta(tester), 1.0);
      await tester.pump(const Duration(milliseconds: 450));
      expect(escalaDeLaTarjeta(tester), 1.0);
      expect(find.text('Empieza aquí'), findsOneWidget);
    });

    testWidgets('solo deja atravesar el objetivo y no cierra al tocar afuera',
        (tester) async {
      var skipped = false;
      var targetTap = false;
      await pumpGuide(
        tester,
        onSkip: () => skipped = true,
        onTargetTap: (_) => targetTap = true,
      );

      expect(find.text('Empieza aquí'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('/8'), findsOneWidget);
      await tester.tapAt(const Offset(210, 290));
      expect(targetTap, isTrue);
      await tester.tapAt(const Offset(8, 8));
      expect(skipped, isFalse);
    });

    testWidgets(
        'la tarjeta nunca solapa el área iluminada ni la barra de navegación',
        (tester) async {
      // Geometría real del emulador (427×952 lógicos) con barra de
      // navegación visible: el hueco del paso "Mira los buses" empieza bajo
      // la pill y deja 310 px libres abajo.
      tester.view.physicalSize = const Size(1280, 2856);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      const bottomInset = 48.0;

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view).copyWith(
            viewPadding: const EdgeInsets.only(bottom: bottomInset),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  const ColoredBox(
                    color: Color(0xFFF8FAFC),
                    child: SizedBox.expand(),
                  ),
                  MapGuideOverlay(
                    target: const Rect.fromLTWH(32, 210, 363, 432),
                    title: 'Mira los buses',
                    message: 'Toca un bus para ver a qué distancia está.',
                    icon: Icons.directions_bus_outlined,
                    stepIndex: 6,
                    stepCount: 9,
                    onSkip: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      final hole = const Rect.fromLTWH(32, 210, 363, 432).inflate(10);
      final card = tester.getRect(find.byKey(const ValueKey('guide_card')));
      expect(card.overlaps(hole), isFalse,
          reason: 'la tarjeta quedó encima del área iluminada');
      expect(card.top, greaterThanOrEqualTo(hole.bottom),
          reason: 'la tarjeta no quedó debajo del área iluminada');
      expect(card.bottom, lessThanOrEqualTo(952 - bottomInset),
          reason: 'la tarjeta quedó bajo la barra de navegación');
      expect(card.top, greaterThanOrEqualTo(0));
    });

    testWidgets('con un hueco bajo la tarjeta va arriba sin tapar el objetivo',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const ColoredBox(
                  color: Color(0xFFF8FAFC),
                  child: SizedBox.expand(),
                ),
                MapGuideOverlay(
                  target: const Rect.fromLTWH(40, 700, 320, 60),
                  title: 'Activa el aviso',
                  message: 'Pulsa este botón para recibir una notificación.',
                  icon: Icons.notifications_active_outlined,
                  stepIndex: 7,
                  stepCount: 9,
                  onSkip: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      final hole = const Rect.fromLTWH(40, 700, 320, 60).inflate(10);
      final card = tester.getRect(find.byKey(const ValueKey('guide_card')));
      expect(card.overlaps(hole), isFalse);
      expect(card.bottom, lessThanOrEqualTo(hole.top));
    });

    // Un iPhone con isla y barra de inicio: 47 px arriba y 34 abajo.
    Future<void> pumpEnIphone(WidgetTester tester, Rect target,
        {bool cartaAbajo = false}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const ColoredBox(
                  color: Color(0xFFF8FAFC),
                  child: SizedBox.expand(),
                ),
                MapGuideOverlay(
                  target: target,
                  title: 'Mira los buses',
                  message: 'Estos iconos representan los buses en vivo.',
                  icon: Icons.directions_bus_outlined,
                  stepIndex: 5,
                  stepCount: 8,
                  cartaAbajo: cartaAbajo,
                  onSkip: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
    }

    testWidgets('con cartaAbajo la tarjeta se apoya abajo aunque pise el hueco',
        (tester) async {
      // El trozo de mapa del paso de los buses: ocupa casi toda la
      // pantalla y la tarjeta no cabe debajo sin pisarlo.
      const target = Rect.fromLTWH(20, 210, 350, 420);
      await pumpEnIphone(tester, target, cartaAbajo: true);

      final card = tester.getRect(find.byKey(const ValueKey('guide_card')));
      expect(card.center.dy, greaterThan(target.center.dy));
      // Entera sobre la barra de inicio, que ocupa los últimos ~13 px.
      expect(card.bottom, lessThanOrEqualTo(844 - 18));
      expect(card.bottom, greaterThan(844 - 34 - 12));
    });

    testWidgets('arriba la tarjeta nunca se mete bajo la isla', (tester) async {
      // Hueco bajo y alto: sin el límite la tarjeta subía hasta y = 0.
      await pumpEnIphone(tester, const Rect.fromLTWH(20, 330, 350, 400));

      final card = tester.getRect(find.byKey(const ValueKey('guide_card')));
      expect(card.top, greaterThanOrEqualTo(47 + 8));
    });

    testWidgets('Saltar guía y acción primaria son explícitos', (tester) async {
      var skipped = false;
      var primary = false;
      await pumpGuide(
        tester,
        onSkip: () => skipped = true,
        onTargetTap: (_) {},
        primaryLabel: 'Continuar',
        onPrimary: () => primary = true,
      );

      // El CTA de la guía se pinta a mano y su nodo lleva
      // `excludeSemantics`: ninguna guía de contraste lo alcanza.
      final boton = find.byKey(const ValueKey('guide_primary'));
      exigeContraste(
        contraste(letraDe(tester, boton), fondoDeBoton(tester, boton)),
        4.5,
        'el CTA primario de la guía',
      );
      await tester.tap(boton);
      expect(primary, isTrue);
      await tester.tap(find.byKey(const ValueKey('guide_skip')));
      expect(skipped, isTrue);
    });

    // «Atrás» y «Saltar guía» medían 36 de alto: debajo de los 48 que
    // piden Android y la propia app para todo lo que se toca (AUD16-06).
    testWidgets('Atrás y Saltar guía se tocan con 48 de alto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapGuideOverlay(
              target: const Rect.fromLTWH(160, 260, 100, 64),
              title: 'Elige tu ruta',
              message: 'Después selecciona la ruta.',
              icon: Icons.alt_route_outlined,
              stepIndex: 3,
              stepCount: 9,
              onBack: () {},
              onSkip: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      for (final clave in ['guide_back', 'guide_skip']) {
        expect(tester.getSize(find.byKey(ValueKey(clave))).height,
            greaterThanOrEqualTo(48),
            reason: clave);
      }
    });

    testWidgets('el paso final queda centrado y solo permite finalizar',
        (tester) async {
      var outsideTap = false;
      var finalized = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () => outsideTap = true,
                  child: const ColoredBox(
                    color: Color(0xFFF8FAFC),
                    child: SizedBox.expand(),
                  ),
                ),
                MapGuideOverlay(
                  target: Rect.zero,
                  centered: true,
                  title: 'Sigue con lo tuyo',
                  message: 'Puedes cambiar de aplicación.',
                  icon: Icons.phone_android_outlined,
                  stepIndex: 8,
                  stepCount: 9,
                  primaryLabel: 'Finalizar guía',
                  onPrimary: () => finalized = true,
                  onSkip: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('Sigue con lo tuyo'), findsOneWidget);
      expect(find.text('Finalizar guía'), findsOneWidget);
      expect(find.byKey(const ValueKey('guide_skip')), findsNothing);
      final screen = tester.getSize(find.byType(Scaffold));
      final card = tester.getRect(find.byKey(const ValueKey('guide_card')));
      expect((card.center.dy - screen.height / 2).abs(), lessThan(30));

      await tester.tapAt(const Offset(8, 8));
      expect(outsideTap, isFalse);
      await tester.tap(find.byKey(const ValueKey('guide_primary')));
      expect(finalized, isTrue);
    });
  });

  group('LocationStatusChip: Quitar y Usar GPS', () {
    Future<ProviderContainer> montar(
        WidgetTester tester, _FakeLocation location) async {
      final container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => location),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: LocationStatusChip()),
            ),
          ),
        ),
      );
      return container;
    }

    // El dueño, 2026-10-19: con un bus tocado la hoja ya dice a qué
    // distancia viene; la píldora de cuántos buses hay cerca sobra y tapa.
    testWidgets('al tocar un bus la píldora se va; al soltarlo vuelve',
        (tester) async {
      final container = await montar(tester, _FakeLocation());
      expect(find.text('Usando tu ubicación'), findsOneWidget);
      container.read(selectedBusesProvider.notifier).toggleBus('BUS-SQA223');
      await tester.pumpAndSettle();
      expect(find.text('Usando tu ubicación'), findsNothing);
      expect(find.text('Quitar'), findsNothing);
      container.read(selectedBusesProvider.notifier).clear();
      await tester.pumpAndSettle();
      expect(find.text('Usando tu ubicación'), findsOneWidget);
    });

    testWidgets('con un bus tocado, un problema de ubicación sí se dice',
        (tester) async {
      final container = await montar(
          tester,
          _FakeLocation(
              const UserLocationState(mode: UserLocationMode.denied)));
      container.read(selectedBusesProvider.notifier).toggleBus('BUS-SQA223');
      await tester.pumpAndSettle();
      expect(find.text('Sin ubicación'), findsOneWidget);
    });

    // El dueño, 2026-10-07: «Fijar» clavaba el pin donde ya estaba y
    // «Quitar» volvía al GPS en el mismo sitio; ninguno se veía hacer nada.
    // Con el GPS, «Quitar» deja el mapa sin punto para tocar otro.
    testWidgets('con GPS ofrece Quitar, no Fijar', (tester) async {
      final location = _FakeLocation();
      await montar(tester, location);
      expect(find.text('Fijar'), findsNothing);
      await tester.tap(find.text('Quitar'));
      expect(location.cleared, isTrue);
      expect(location.fixedPin, isFalse);
    });

    testWidgets('sin punto invita a usar el GPS', (tester) async {
      final location = _FakeLocation(
          const UserLocationState(mode: UserLocationMode.sinPunto));
      await montar(tester, location);
      expect(find.text('Sin punto de espera'), findsOneWidget);
      await tester.tap(find.text('Usar GPS'));
      expect(location.gpsAsked, isTrue);
    });
  });

  testWidgets('en ubicación sin pin ilumina y permite tocar el GPS',
      (tester) async {
    final mapa = await MapaDePrueba.montar(
      tester,
      conPosicionInicial: false,
    );
    mapa.ubicacion.state =
        const UserLocationState(mode: UserLocationMode.sinPunto);
    mapa.container.read(mapPreparingProvider.notifier).state = false;
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await mapa.container.read(mapGuideProvider.notifier).restart(
          hasLocation: false,
          locationSettled: true,
        );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final boton = tester.getRect(find.text('Usar GPS'));
    final overlay =
        tester.widget<MapGuideOverlay>(find.byType(MapGuideOverlay));
    final hueco = overlay.target.inflate(overlay.targetPadding);
    final carta = tester.getRect(find.byKey(const ValueKey('guide_card')));
    expect(hueco.contains(boton.topLeft), isTrue);
    expect(hueco.contains(boton.bottomRight), isTrue);
    expect(carta.overlaps(boton), isFalse);

    await tester.tap(find.text('Usar GPS'));
    expect(mapa.ubicacion.gpsPedido, 1);
    await mapa.desmontar(tester);
  });

  testWidgets('la guía ilumina Reintentar y Abrir sin posición',
      (tester) async {
    final mapa = await MapaDePrueba.montar(
      tester,
      conPosicionInicial: false,
    );
    mapa.container.read(mapPreparingProvider.notifier).state = false;
    await mapa.container.read(mapGuideProvider.notifier).restart(
          hasLocation: false,
          locationSettled: true,
        );

    Future<void> comprobarPildora(
        UserLocationMode mode, String textoAccion) async {
      mapa.ubicacion.state = UserLocationState(mode: mode);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final boton = tester.getRect(find.text(textoAccion));
      final overlay =
          tester.widget<MapGuideOverlay>(find.byType(MapGuideOverlay));
      final hueco = overlay.target.inflate(overlay.targetPadding);
      final carta = tester.getRect(find.byKey(const ValueKey('guide_card')));
      expect(hueco.contains(boton.topLeft), isTrue, reason: textoAccion);
      expect(hueco.contains(boton.bottomRight), isTrue, reason: textoAccion);
      expect(carta.overlaps(boton), isFalse, reason: textoAccion);
    }

    await comprobarPildora(UserLocationMode.denied, 'Reintentar');
    await comprobarPildora(UserLocationMode.gpsFailed, 'Reintentar');
    await comprobarPildora(UserLocationMode.permanentDenied, 'Abrir');

    await mapa.desmontar(tester);
  });

  testWidgets('el contador del paso dos no usa estilo de error',
      (tester) async {
    Widget montar(int paso) => MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.expand(
              child: MapGuideOverlay(
                target: const Rect.fromLTWH(100, 100, 120, 80),
                title: 'Busca tu ruta',
                message: 'Elige empresa y ruta.',
                icon: Icons.search,
                stepIndex: paso,
                stepCount: 8,
                onSkip: () {},
              ),
            ),
          ),
        );

    await tester.pumpWidget(montar(0));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpWidget(montar(1));
    await tester.pump(const Duration(milliseconds: 450));

    final estilo =
        tester.renderObject<RenderParagraph>(find.text('2')).text.style!;
    expect(estilo.decoration, TextDecoration.none);
    expect(estilo.fontSize, 25);
    expect(estilo.color, AppColors.primaryDeep);
  });
}
