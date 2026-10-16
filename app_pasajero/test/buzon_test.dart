import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show AppColors;
import 'package:ya_viene_pasajero/core/app_info.dart';
import 'package:ya_viene_pasajero/core/router/app_router.dart';
import 'package:ya_viene_pasajero/features/buzon/data/buzon.dart';
import 'package:ya_viene_pasajero/features/buzon/presentation/buzon_screen.dart';
import 'helpers/borde.dart';

/// El botón queda bajo el campo: en la pantalla de prueba (800×600) hay que
/// llevarlo a la vista antes de tocarlo, como haría el pasajero.
Future<void> enviar(WidgetTester tester) async {
  final boton = find.byKey(const ValueKey('buzon_enviar'));
  await tester.ensureVisible(boton);
  await tester.pump();
  await tester.tap(boton);
}

/// El menú tiene un fondo vivo que no se asienta nunca: se espera lo que
/// dura su entrada y la de la pantalla, como en `mas_screen_test.dart`.
Future<void> asentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  /// Los fondos de las pantallas son blancos y lo blanco que va encima se
  /// despega con sombra (dueño, 2026-10-16). La barra de arriba, del mismo
  /// blanco: si no, se lee como una franja de otro papel.
  void exigeFondoBlanco(WidgetTester tester) {
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.surface,
        reason: 'el fondo de el buzón');
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        AppColors.surface,
        reason: 'la barra de el buzón');
  }

  group('Buzon.enviar', () {
    test('manda tipo, texto limpio, plataforma y versión a /api/reportes',
        () async {
      late http.Request pedido;
      final buzon = Buzon(
        backend: () => 'http://x',
        cliente: MockClient((r) async {
          pedido = r;
          return http.Response('{"recibido":true}', 201);
        }),
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        expect(await buzon.enviar(TipoReporte.sugerencia, '  Más rutas \n'),
            EnvioReporte.recibido);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(pedido.method, 'POST');
      expect(pedido.url.toString(), 'http://x/api/reportes');
      expect(pedido.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(pedido.body), {
        'tipo': 'sugerencia',
        'texto': 'Más rutas',
        'plataforma': 'ios',
        'version': kAppVersion,
      });
    });

    test('en Android dice android', () async {
      late Map<String, dynamic> cuerpo;
      final buzon = Buzon(
        backend: () => 'http://x',
        cliente: MockClient((r) async {
          cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('', 201);
        }),
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await buzon.enviar(TipoReporte.problema, 'No carga');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(cuerpo['plataforma'], 'android');
      expect(cuerpo['tipo'], 'problema');
    });

    test('fuera de un teléfono no inventa plataforma', () async {
      late Map<String, dynamic> cuerpo;
      final buzon = Buzon(
        backend: () => 'http://x',
        cliente: MockClient((r) async {
          cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('', 201);
        }),
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await buzon.enviar(TipoReporte.problema, 'No carga');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(cuerpo.containsKey('plataforma'), isFalse);
    });

    test('lee la URL del backend en cada envío (el respaldo puede cambiarla)',
        () async {
      var url = 'http://principal';
      final vistas = <String>[];
      final buzon = Buzon(
        backend: () => url,
        cliente: MockClient((r) async {
          vistas.add(r.url.host);
          return http.Response('', 201);
        }),
      );
      await buzon.enviar(TipoReporte.problema, 'uno');
      url = 'http://respaldo';
      await buzon.enviar(TipoReporte.problema, 'dos');
      expect(vistas, ['principal', 'respaldo']);
    });

    for (final (codigo, esperado) in [
      (429, EnvioReporte.muchos),
      (503, EnvioReporte.noDisponible),
      (400, EnvioReporte.noDisponible),
      (404, EnvioReporte.noDisponible),
      (500, EnvioReporte.noDisponible),
    ]) {
      test('$codigo es $esperado', () async {
        final buzon = Buzon(
          backend: () => 'http://x',
          cliente: MockClient((_) async => http.Response('', codigo)),
        );
        expect(await buzon.enviar(TipoReporte.problema, 'abc'), esperado);
      });
    }

    test('sin red es sinRed, sin lanzar', () async {
      final buzon = Buzon(
        backend: () => 'http://x',
        cliente: MockClient((_) async => throw http.ClientException('caído')),
      );
      expect(
          await buzon.enviar(TipoReporte.problema, 'abc'), EnvioReporte.sinRed);
    });
  });

  group('BuzonScreen', () {
    Future<void> abrir(WidgetTester tester, Buzon buzon) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [buzonProvider.overrideWithValue(buzon)],
          child: const MaterialApp(home: BuzonScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('el buzón va sobre blanco', (tester) async {
      await abrir(
          tester,
          Buzon(
            backend: () => 'http://x',
            cliente: MockClient((_) async => http.Response('', 201)),
          ));
      exigeFondoBlanco(tester);
    });

    testWidgets('el formulario se funde bajo la barra al subir',
        (tester) async {
      await abrir(
          tester,
          Buzon(
            backend: () => 'http://x',
            cliente: MockClient((_) async => http.Response('', 201)),
          ));
      exigeBordeDesvanecido(
          tester,
          find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Text))
              .first);
    });

    FilledButton boton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(const ValueKey('buzon_enviar')));

    testWidgets('el botón se enciende con 3 caracteres y no con espacios',
        (tester) async {
      await abrir(
          tester,
          Buzon(
              backend: () => 'http://x',
              cliente: MockClient((_) async => http.Response('', 201))));
      expect(boton(tester).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('buzon_texto')), 'ab');
      await tester.pump();
      expect(boton(tester).onPressed, isNull);
      await tester.enterText(
          find.byKey(const ValueKey('buzon_texto')), '      ');
      await tester.pump();
      expect(boton(tester).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('buzon_texto')), 'abc');
      await tester.pump();
      expect(boton(tester).onPressed, isNotNull);
    });

    testWidgets('la pregunta es el título, sin ícono ni repetirla',
        (tester) async {
      await abrir(
          tester,
          Buzon(
              backend: () => 'http://x',
              cliente: MockClient((_) async => http.Response('', 201))));
      expect(
        find.descendant(
            of: find.byType(AppBar),
            matching: find.text('¿Qué nos quieres contar?')),
        findsOneWidget,
      );
      expect(find.text('¿Qué nos quieres contar?'), findsOneWidget);
      expect(find.byIcon(Icons.forum_outlined), findsNothing);
      expect(find.text('Lo leemos todo y nos ayuda a mejorar Ya Viene.'),
          findsOneWidget);
    });

    testWidgets('el campo no deja pasar de 1000', (tester) async {
      await abrir(
          tester,
          Buzon(
              backend: () => 'http://x',
              cliente: MockClient((_) async => http.Response('', 201))));
      final campo =
          tester.widget<TextField>(find.byKey(const ValueKey('buzon_texto')));
      expect(campo.maxLength, Buzon.maximo);
    });

    testWidgets('manda el tipo elegido, muestra la espera y luego las gracias',
        (tester) async {
      final respuesta = Completer<http.Response>();
      late Map<String, dynamic> cuerpo;
      await abrir(
        tester,
        Buzon(
          backend: () => 'http://x',
          cliente: MockClient((r) {
            cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
            return respuesta.future;
          }),
        ),
      );
      // Arranca en «Un problema», elegida para el lector.
      expect(
        tester.getSemantics(find.byKey(const ValueKey('buzon_problema'))),
        matchesSemantics(
            label: 'Un problema',
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            hasTapAction: true),
      );
      await tester.tap(find.byKey(const ValueKey('buzon_sugerencia')));
      await tester.pump();
      expect(find.textContaining('Qué mejorarías'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('buzon_texto')), 'Más rutas de noche');
      await enviar(tester);
      await tester.pump();

      // Sin aro que gira: el botón dice lo que hace, sigue verde y una
      // barra de 2 px corre por su filo de abajo (referentes: Geist).
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Enviando…'), findsOneWidget);
      final barra = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(barra.minHeight, 2);
      expect(tester.getSize(find.byType(LinearProgressIndicator)).height, 2);
      final estilo = boton(tester).style!;
      expect(estilo.backgroundColor!.resolve({WidgetState.disabled}),
          AppColors.primary,
          reason: 'enviando no es apagado: el verde se queda');
      expect(estilo.foregroundColor!.resolve({WidgetState.disabled}),
          Colors.white);
      expect(boton(tester).onPressed, isNull,
          reason: 'un segundo toque no manda dos veces');

      respuesta.complete(http.Response('', 201));
      await tester.pumpAndSettle();
      expect(cuerpo['tipo'], 'sugerencia');
      expect(cuerpo['texto'], 'Más rutas de noche');
      expect(find.text('Gracias, lo recibimos'), findsOneWidget);
      expect(find.byKey(const ValueKey('buzon_formulario')), findsNothing);
    });

    for (final (codigo, mensaje) in [
      (429, 'Ya enviaste varios hace poco'),
      (503, 'El buzón no está disponible ahora'),
      (null, 'Revisa tu conexión'),
    ]) {
      testWidgets('si falla (${codigo ?? 'sin red'}) lo dice y guarda el texto',
          (tester) async {
        var intentos = 0;
        await abrir(
          tester,
          Buzon(
            backend: () => 'http://x',
            cliente: MockClient((_) async {
              intentos++;
              if (intentos > 1) return http.Response('', 201);
              if (codigo == null) throw http.ClientException('caído');
              return http.Response('', codigo);
            }),
          ),
        );
        await tester.enterText(
            find.byKey(const ValueKey('buzon_texto')), 'El bus no aparece');
        await enviar(tester);
        await tester.pumpAndSettle();

        expect(find.textContaining(mensaje), findsOneWidget);
        expect(find.text('El bus no aparece'), findsOneWidget);
        expect(find.text('Intentar de nuevo'), findsOneWidget);

        await enviar(tester);
        await tester.pumpAndSettle();
        expect(intentos, 2);
        expect(find.text('Gracias, lo recibimos'), findsOneWidget);
      });
    }
  });

  testWidgets('«Volver» lleva al mapa y el buzón queda limpio', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      initialLocation: AppRoutes.buzon,
      routes: [
        GoRoute(
          path: AppRoutes.map,
          builder: (_, __) => const Scaffold(body: Text('el mapa')),
        ),
        GoRoute(path: AppRoutes.buzon, builder: (_, __) => const BuzonScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buzonProvider.overrideWithValue(Buzon(
              backend: () => 'http://x',
              cliente: MockClient((_) async => http.Response('', 201)))),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await asentar(tester);
    // Es una pestaña: no hay flecha de volver.
    expect(find.byTooltip('Volver'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('buzon_texto')), 'Hola');
    await enviar(tester);
    await asentar(tester);
    await tester.tap(find.byKey(const ValueKey('buzon_volver')));
    await asentar(tester);
    expect(find.text('el mapa'), findsOneWidget);

    // De vuelta al buzón: el formulario en blanco, no las gracias de antes.
    router.go(AppRoutes.buzon);
    await asentar(tester);
    expect(find.text('Gracias, lo recibimos'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('buzon_texto')))
          .controller!
          .text,
      isEmpty,
    );
  });

  test('la app tiene la ruta /buzon', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Vive dentro de la rama «Buzón» del shell de la barra de abajo.
    expect(
      container.read(appRouterProvider).namedLocation('buzon'),
      AppRoutes.buzon,
    );
  });
}
