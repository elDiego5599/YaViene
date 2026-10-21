import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/dialogo.dart';
import 'package:ya_viene_pasajero/core/widgets/pildora_navegacion.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'bienvenida.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'map_tour_overlay.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/mas_screen.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/'
    'providers/proximity_alerts_provider.dart';
import 'package:ya_viene_pasajero/features/onboarding/presentation/screens/'
    'onboarding_screen.dart';

import 'golden/golden_harness.dart';
import 'helpers/contraste.dart';

/// Los botones y rótulos que la suite de accesibilidad no alcanza a medir:
///
/// El CTA de la hoja vive bajo un `Semantics(excludeSemantics: true)`, el de
/// la bienvenida se bombea deshabilitado, y el del diálogo, el de la guía y
/// la pastilla del drawer no están en ninguna guía de contraste. Aquí se
/// leen los colores YA PINTADOS de cada superficie y se exige la vara de la
/// WCAG: sin color que valga, la prueba cae.
void main() {
  SharedPreferences.setMockInitialValues({});

  const userLat = 6.2442;
  const userLon = -75.5812;

  RouteInfo routeR1() => const RouteInfo(
        id: 'R1',
        name: 'Ruta 1',
        companyId: 'C1',
      );

  BusPosition busAt(
    double latOffset, {
    String busId = 'A-1',
    bool ghost = false,
    DateTime? timestamp,
  }) =>
      BusPosition(
        busId: busId,
        routeId: 'R1',
        lat: userLat + latOffset,
        lon: userLon,
        heading: 0,
        speedKmh: 30,
        timestamp: timestamp ?? DateTime.now(),
        isGhostBus: ghost,
      );

  testWidgets('el botón principal del diálogo pasa AA', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(builder: (context) {
          ctx = context;
          return const Scaffold();
        }),
      ),
    );
    unawaited(
      mostrarDialogo<bool>(
        ctx,
        (d) => Dialogo(
          icono: Icons.restart_alt_outlined,
          titulo: '¿Reiniciar la guía?',
          mensaje: 'Vas a perder la ruta.',
          delicado: false,
          principal: DialogoAccion('Reiniciar guía', () {
            Navigator.pop(d, true);
          }),
          secundaria: DialogoAccion('Cancelar', () {
            Navigator.pop(d, false);
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boton = find.byType(FilledButton);
    exigeContraste(
      contraste(letraDe(tester, boton), fondoDeBoton(tester, boton)),
      4.5,
      'el botón principal del diálogo',
    );
  });

  testWidgets('el CTA de la bienvenida, con el aviso aceptado, pasa AA',
      (tester) async {
    fijarPantalla(tester);
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/map',
          builder: (context, state) => const Scaffold(body: Text('el mapa')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: const Locale('es', 'CO'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    // El CTA solo se pinta habilitado: sin la casilla, el estilo resuelto
    // es el del estado deshabilitado y no es el color que ve el usuario
    // cuando puede actuar.
    await tester.tap(find.byKey(const ValueKey('legal_accept')));
    await tester.pump();

    final boton = find.byType(ElevatedButton);
    expect(tester.widget<ElevatedButton>(boton).onPressed, isNotNull);
    exigeContraste(
      contraste(letraDe(tester, boton), fondoDeBoton(tester, boton)),
      4.5,
      'el CTA de la bienvenida',
    );
  });

  testWidgets('la bienvenida y onboarding usan tinta sobre el verde de marca',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: VentanaBienvenida(alVerGuia: () {}, alIrALaApp: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));

    final guia = find.text('Ver la guía');
    exigeContraste(contraste(letraDe(tester, guia), AppColors.primary), 4.5,
        'Ver la guía sobre el verde de marca');

    await tester.pumpWidget(
      ProviderScope(child: marcoGoldenRuteado(const OnboardingScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.byKey(const ValueKey('legal_accept')));
    await tester.pump();

    final ubicacion = find.text('Permitir ubicación');
    exigeContraste(
      contraste(letraDe(tester, ubicacion), AppColors.primary),
      4.5,
      'Permitir ubicación sobre el verde de marca',
    );
  });

  group('la hoja de distancia pinta sus tres estados con vara AA', () {
    Future<ProviderContainer> pumpHoja(
      WidgetTester tester,
      List<BusPosition> buses,
    ) async {
      final container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _TestUserLocation()),
        busPositionsSourceProvider.overrideWith(
          (ref, routeId) => Stream.value(buses),
        ),
        // El recorrido pasa por el punto del usuario: lo que se prueba es
        // el color, no la regla de «esta ruta no pasa cerca».
        routeTrajectoryProvider.overrideWith(
          (ref, routeId) => RouteTrajectory(
            routeId: routeId,
            routeName: 'Ruta 1',
            points: const [
              GeoPoint(lat: userLat, lon: userLon - 0.05),
              GeoPoint(lat: userLat, lon: userLon + 0.05),
            ],
          ),
        ),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: EtaBottomSheet()),
          ),
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
      container.read(selectedRouteProvider.notifier).select(routeR1());
      container.read(selectedBusesProvider.notifier).toggleBus('A-1');
      await tester.pump();
      await tester.pump();
      // La tarjeta y el color del botón se asientan: medir a mitad de
      // animación es medir un cuadro que nadie ve.
      await tester.pump(const Duration(milliseconds: 400));
      return container;
    }

    void exigeCTA(WidgetTester tester, String etiqueta, String razon) {
      final texto = find.text(etiqueta);
      expect(texto, findsOneWidget, reason: razon);
      exigeContraste(
        contraste(
          letraDe(tester, texto),
          fondoDelContenedor(tester, texto),
        ),
        4.5,
        razon,
      );
    }

    testWidgets('estado normal: verde de marca con letra blanca',
        (tester) async {
      await pumpHoja(tester, [busAt(0.02)]);
      exigeCTA(
        tester,
        'Avisarme cuando esté cerca',
        'el CTA normal de la hoja',
      );
    });

    testWidgets('estado bloqueado: el gris del botón también se lee',
        (tester) async {
      // 400 m: más cerca que el aviso más corto que se puede pedir (500 m)
      // → bloqueado. El botón dice «El bus ya está cerca» y se pinta gris con
      // letra blanca.
      await pumpHoja(tester, [busAt(0.0036)]);
      exigeCTA(
        tester,
        'El bus ya está cerca',
        'el CTA bloqueado de la hoja',
      );
    });

    testWidgets('estado activo: aviso armado', (tester) async {
      final container = await pumpHoja(tester, [busAt(0.02)]);
      container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
      container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
      await tester.pump();
      // El color del botón transiciona de verde a verde oscuro: medir el
      // cuadro asentado, no el del cruce.
      await tester.pump(const Duration(milliseconds: 400));

      final texto = find.text('Aviso activado');
      expect(texto, findsOneWidget);
      exigeContraste(
        contraste(
          letraDe(tester, texto),
          fondoDelContenedor(tester, texto),
        ),
        4.5,
        'el CTA de aviso activo',
      );
    });

    testWidgets('sin señal: el aviso de «conserva su última posición» se lee',
        (tester) async {
      await pumpHoja(tester, [
        busAt(
          0.02,
          ghost: true,
          timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
        ),
      ]);

      final stale = find.textContaining('conserva su última posición');
      expect(stale, findsOneWidget);
      exigeContraste(
        contraste(letraDe(tester, stale), AppColors.surface),
        4.5,
        'el texto de bus sin señal',
      );
    });
  });

  testWidgets('el aviso del tooltip de la guía y su contador se leen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
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
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    // Sin acción primaria el tooltip escribe este aviso en verde de marca,
    // y la fracción de pasos en gris apagado: los dos van sobre la carta
    // blanca.
    final aviso = find.text('Toca el área iluminada para continuar');
    expect(aviso, findsOneWidget);
    exigeContraste(
      contraste(letraDe(tester, aviso), AppColors.surface),
      4.5,
      'el aviso del tooltip de la guía',
    );
    final contador = find.text('/8');
    expect(contador, findsOneWidget);
    exigeContraste(
      contraste(letraDe(tester, contador), AppColors.surface),
      4.5,
      'la fracción de pasos de la guía',
    );
  });

  testWidgets('la barra de abajo pasa AA: rótulos, cápsula y cuenta',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: PildoraNavegacion(
            indice: 0,
            avisosActivos: 1,
            alElegir: (_) {},
          ),
        ),
      ),
    ));

    // La pastilla con la cuenta de avisos.
    final pastilla = find.text('1');
    expect(pastilla, findsOneWidget);
    exigeContraste(
      contraste(
        letraDe(tester, pastilla),
        fondoDelContenedor(tester, pastilla),
      ),
      4.5,
      'la pastilla de avisos de la barra',
    );
    // La pestaña puesta va en verde sobre su cápsula verde clara; las
    // demás, en gris sobre el blanco de la píldora.
    exigeContraste(
      contraste(letraDe(tester, find.text('Mapa')), AppColors.primaryTint),
      4.5,
      'la pestaña puesta sobre su cápsula',
    );
    exigeContraste(
      contraste(letraDe(tester, find.text('Info')), Colors.white),
      4.5,
      'una pestaña sin poner',
    );
  });

  testWidgets('los rótulos de Info, en sus tarjetas blancas, pasan AA',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen<RouteInfo?>(
      selectedRouteProvider,
      (_, __) {},
    );
    addTearDown(sub.close);
    container.read(selectedRouteProvider.notifier).select(const RouteInfo(
          id: 'R1',
          name: 'B18 Tcherassi',
          companyId: 'C1',
          terminalA: 'Mallorquín',
          terminalB: 'La Playa',
        ));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MasScreen()),
      ),
    );
    await tester.pump();

    // Sobre la malla, las tarjetas son blancas y se despegan con sombra
    // (dueño, 2026-10-16): la letra se mide contra su blanco, que tiene
    // que ser opaco o la malla se trasluce y la medida miente.
    for (final (texto, que) in [
      ('Ruta activa', '«Ruta activa»'),
      ('B18 Tcherassi', 'el nombre de la ruta'),
      ('Mallorquín', 'los terminales'),
      ('Privacidad', 'las filas'),
    ]) {
      final rotulo = find.text(texto);
      expect(rotulo, findsOneWidget);
      final fondo = fondoDelContenedor(tester, rotulo);
      expect(fondo.a, 1.0, reason: 'la tarjeta de $que deja ver la malla');
      exigeContraste(
        contraste(letraDe(tester, rotulo), fondo),
        4.5,
        '$que sobre su tarjeta',
      );
    }
  });
}

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}
