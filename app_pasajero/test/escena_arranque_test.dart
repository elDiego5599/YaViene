import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/router/app_router.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/screens/splash_screen.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/widgets/escena_arranque.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/widgets/fondo_matizado.dart';

/// El arranque (dueño, 2026-10-18): fondo blanco, Barranquilla que se arma
/// —la Ventana al Mundo, la cayena y el bus— y la marca. Breve: la escena
/// entera dura [EscenaArranque.duracion] y el arranque sigue apenas termina.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GoRouter> abrir(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [
      backendUrlProvider.overrideWith(() => BackendUrl.fija('http://x')),
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
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    return router;
  }

  testWidgets('el arranque es blanco y pinta la escena con la marca',
      (tester) async {
    await abrir(tester);
    await tester.pump();

    final fondo = tester.widget<Scaffold>(find.descendant(
      of: find.byType(SplashScreen),
      matching: find.byType(Scaffold),
    ));
    expect(fondo.backgroundColor, Colors.white);
    expect(find.byType(EscenaArranque), findsOneWidget);
    expect(find.text('Ya Viene'), findsOneWidget);
    // El logo sigue volando a la bienvenida.
    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == InkHero.marcaHeroTag),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Abriendo Ya Viene'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  // «Que en la pantalla de carga no se vea el blanco liso» (dueño,
  // 2026-10-18): el matizado va debajo de la escena; el blanco del Scaffold
  // queda detrás, para el relevo con el arranque nativo.
  testWidgets('el arranque lleva el fondo matizado debajo de la escena',
      (tester) async {
    await abrir(tester);
    await tester.pump();
    final pila = tester.widget<Stack>(find
        .descendant(of: find.byType(SplashScreen), matching: find.byType(Stack))
        .first);
    expect(pila.children.first, isA<FondoMatizado>());
    expect(
        find.descendant(
            of: find.byWidget(pila), matching: find.byType(EscenaArranque)),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('sigue apenas termina la escena, ni antes ni mucho después',
      (tester) async {
    final router = await abrir(tester);
    await tester.pump();
    await tester
        .pump(EscenaArranque.duracion - const Duration(milliseconds: 50));
    expect(router.routeInformationProvider.value.uri.path, '/');

    await tester.pump(const Duration(milliseconds: 100));
    // La bienvenida respira para siempre: se avanza un tiempo fijo.
    await tester.pump(const Duration(seconds: 1));
    expect(router.routeInformationProvider.value.uri.path, '/onboarding');
  });

  testWidgets('la escena es breve: menos de 1,8 s', (tester) async {
    expect(EscenaArranque.duracion.inMilliseconds, lessThan(1800));
  });

  // «Que dure un poquitito más cuando aparece el texto» (dueño, 2026-10-18).
  testWidgets('la marca se queda entera medio segundo antes de seguir',
      (tester) async {
    final entera = EscenaArranque.duracion * EscenaArranque.marca.end;
    expect(EscenaArranque.duracion - entera,
        greaterThanOrEqualTo(EscenaArranque.lecturaMarca));
    expect(
        EscenaArranque.lecturaMarca.inMilliseconds, greaterThanOrEqualTo(450));
    // Lo de antes no se alargó: la flor y el bus terminan como antes.
    expect(EscenaArranque.duracion * EscenaArranque.bus.end,
        const Duration(milliseconds: 1075));
  });

  // «Un poco más detalladita la flor» (dueño, 2026-10-18), como la cayena
  // de referencia: el ojo oscuro del centro con sus rayas, la orla clara
  // del borde y la columna con polen y estigmas.
  Future<Color Function(Offset)> pintarFlor(WidgetTester tester) async {
    // La flor de 200 (radio 100) con aire alrededor: los pétalos pasan un
    // poco del radio.
    const lado = 240;
    late ByteData datos;
    await tester.runAsync(() async {
      final grabadora = ui.PictureRecorder();
      final lienzo = Canvas(grabadora)..translate(20, 20);
      PintorCayena(1).paint(lienzo, const Size(200, 200));
      final imagen = await grabadora.endRecording().toImage(lado, lado);
      datos = (await imagen.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    return (o) {
      final i = ((o.dy + 20).floor() * lado + (o.dx + 20).floor()) * 4;
      return Color.fromARGB(datos.getUint8(i + 3), datos.getUint8(i),
          datos.getUint8(i + 1), datos.getUint8(i + 2));
    };
  }

  testWidgets('la cayena trae las rayas del centro', (tester) async {
    final en = await pintarFlor(tester);
    // Una vuelta a 0,3 del radio, lejos de la columna: las rayas oscuras
    // del ojo hacen que el brillo suba y baje muchas veces.
    var cambios = 0;
    double? antes;
    for (var g = 0.0; g < 360; g += 0.5) {
      final a = g * math.pi / 180;
      final c =
          en(const Offset(100, 100) + Offset(math.cos(a), math.sin(a)) * 30);
      final brillo = c.computeLuminance();
      if (antes != null && (brillo - antes).abs() > 0.012) cambios++;
      antes = brillo;
    }
    // La flor lisa de antes daba 41; la de rayas, 113.
    expect(cambios, greaterThanOrEqualTo(80), reason: 'medido: $cambios');
  });

  testWidgets('la cayena tiene su orla clara y el borde ondulado',
      (tester) async {
    final en = await pintarFlor(tester);
    // Sobre el eje de un pétalo (el de la derecha, ya girado a su sitio; el
    // de arriba lleva la columna encima): cerca del borde es más claro que a
    // media hoja.
    const eje = Offset(0.951, -0.309);
    double brilloEn(double fraccion) =>
        en(const Offset(100, 100) + eje * (100 * fraccion)).computeLuminance();
    expect(brilloEn(0.9), greaterThan(brilloEn(0.6) * 1.15));
    // El borde de arriba no es un arco liso: el alcance del pétalo sube y
    // baja a lo ancho (las ondas de la cayena).
    final alcances = <int>[];
    for (var x = 80; x <= 120; x += 2) {
      var y = -20;
      while (y < 100 && en(Offset(x.toDouble(), y.toDouble())).a < 0.5) {
        y++;
      }
      alcances.add(y);
    }
    // Cuenta los cambios de sentido; los tramos planos no cortan la cuenta.
    var vueltas = 0;
    var sentido = 0;
    for (var i = 1; i < alcances.length; i++) {
      final d = (alcances[i] - alcances[i - 1]).sign;
      if (d == 0) continue;
      if (sentido != 0 && d != sentido) vueltas++;
      sentido = d;
    }
    expect(vueltas, greaterThanOrEqualTo(2), reason: '$alcances');
  });

  // «Se ve muy grande y redonda» (dueño, 2026-10-18, con la cayena de
  // referencia): cinco pétalos sueltos, con muesca entre uno y otro, no un
  // disco; y más chica en la escena.
  testWidgets('los pétalos van sueltos: cinco muescas alrededor',
      (tester) async {
    final en = await pintarFlor(tester);
    // Una vuelta a 0,85 del radio: cada muesca es un tramo sin flor.
    var muescas = 0;
    bool? dentroAntes;
    for (var g = 0.0; g <= 360; g += 0.5) {
      final a = g * math.pi / 180;
      final dentro =
          en(const Offset(100, 100) + Offset(math.cos(a), math.sin(a)) * 85).a >
              0.5;
      if (dentroAntes == true && !dentro) muescas++;
      dentroAntes = dentro;
    }
    expect(muescas, 5);
  });

  testWidgets('la cayena va más chica en la escena', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: EscenaArranque()))));
    final flor = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PintorCayena);
    expect(tester.getSize(flor).width, lessThanOrEqualTo(116));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('la columna lleva polen amarillo y cinco estigmas rojos',
      (tester) async {
    expect(PintorCayena.anteras, greaterThanOrEqualTo(12));
    expect(PintorCayena.estigmas, 5);
    final en = await pintarFlor(tester);
    var amarillo = 0;
    for (var y = 20; y < 100; y++) {
      for (var x = 70; x < 130; x++) {
        final c = en(Offset(x.toDouble(), y.toDouble()));
        if (c.r > 0.85 && c.g > 0.65 && c.b < 0.35) amarillo++;
      }
    }
    expect(amarillo, greaterThan(60));
  });

  testWidgets('con «Reducir movimiento» sale armada y quieta', (tester) async {
    var termino = false;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: EscenaArranque(alTerminar: () => termino = true)),
        ),
      ),
    ));
    await tester.pump();
    // Sin animación: ningún cuadro pide repintar.
    expect(tester.binding.hasScheduledFrame, isFalse);
    final torre = tester.widget<CustomPaint>(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PintorVentana));
    expect((torre.painter! as PintorVentana).avance, 1);
    expect(termino, isFalse);
    await tester.pump(EscenaArranque.quieta);
    expect(termino, isTrue);
  });

  // «Quita las estrellas y caracoles de la pantalla de carga» (dueño,
  // 2026-10-18): antes tenía un arco de siete encima de la torre.
  // Luego pidió el suelo con arbustos: eso sí, y nada más.
  testWidgets('sin adornos: solo la torre, su suelo y la cayena se pintan',
      (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: Scaffold(body: Center(child: EscenaArranque()))),
    ));
    final pintores = tester
        .widgetList<CustomPaint>(find.descendant(
            of: find.byType(EscenaArranque),
            matching: find.byType(CustomPaint)))
        .map((c) => c.painter)
        .whereType<CustomPainter>()
        .map((p) => p.runtimeType)
        .toSet();
    expect(pintores, {PintorVentana, PintorSuelo, PintorCayena});
    await tester.pump(EscenaArranque.quieta);
  });

  // «Que la Ventana al Mundo tuviera como su suelo con arbusticos» (dueño,
  // 2026-10-18): la torre y la flor se paran en una isla de pasto.
  testWidgets('la torre se para en un suelo con arbustos', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: EscenaArranque()))));
    await tester.pump(const Duration(seconds: 2));

    final suelo = find
        .byWidgetPredicate((w) => w is CustomPaint && w.painter is PintorSuelo);
    final torre = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PintorVentana);
    expect(suelo, findsOneWidget);
    final s = tester.getRect(suelo), t = tester.getRect(torre);
    expect(s.top, lessThan(t.bottom), reason: 'la torre queda en el aire');
    expect(s.bottom, greaterThan(t.bottom),
        reason: 'la torre queda en el aire');
    expect(s.left, lessThan(t.left));
    expect(PintorSuelo.arbustos, greaterThanOrEqualTo(3));
    // Va detrás del bus y de la flor: no los tapa.
    final pila = tester.widget<Stack>(find
        .descendant(
            of: find.byType(EscenaArranque), matching: find.byType(Stack))
        .first);
    final orden = [
      for (final h in pila.children)
        ((h as Positioned).child is CustomPaint)
            ? ((h.child as CustomPaint).painter).runtimeType
            : Widget,
    ];
    expect(orden, [PintorVentana, PintorSuelo, PintorCayena, Widget]);
  });

  testWidgets('el suelo es verde y aparece con la torre', (tester) async {
    const w = 280, h = 56;
    Future<List<Color>> pintar(double avance) async {
      late ByteData datos;
      await tester.runAsync(() async {
        final grabadora = ui.PictureRecorder();
        PintorSuelo(avance)
            .paint(Canvas(grabadora), Size(w.toDouble(), h.toDouble()));
        final imagen = await grabadora.endRecording().toImage(w, h);
        datos = (await imagen.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });
      return [
        for (var i = 0; i < w * h; i++)
          Color.fromARGB(datos.getUint8(i * 4 + 3), datos.getUint8(i * 4),
              datos.getUint8(i * 4 + 1), datos.getUint8(i * 4 + 2)),
      ];
    }

    expect((await pintar(0)).every((c) => c.a == 0), isTrue,
        reason: 'antes de la torre no hay suelo');
    final px = await pintar(1);
    final verdes =
        px.where((c) => c.a > 0.9 && c.g - c.r > 0.15 && c.g - c.b > 0.1);
    expect(verdes.length, greaterThan(px.length ~/ 4),
        reason: 'verdes ${verdes.length}');
    expect(PintorSuelo(1).shouldRepaint(PintorSuelo(0.5)), isTrue);
  });
}
