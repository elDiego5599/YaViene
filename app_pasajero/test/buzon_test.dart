import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/core/geo/celda_busqueda.dart';
import 'package:ya_viene_core/ya_viene_core.dart'
    show
        AppColors,
        BusPosition,
        Company,
        RouteInfo,
        companiesProvider,
        routesByCompanyProvider,
        selectedRouteProvider;
import 'package:ya_viene_pasajero/core/app_info.dart';
import 'package:ya_viene_pasajero/core/router/app_router.dart';
import 'package:ya_viene_pasajero/core/widgets/cabecera_degradada.dart';
import 'package:ya_viene_pasajero/core/widgets/fondo_texturizado.dart';
import 'package:ya_viene_pasajero/core/widgets/titulo_seccion.dart';
import 'package:ya_viene_pasajero/features/buzon/data/buzon.dart';
import 'package:ya_viene_pasajero/features/buzon/presentation/buzon_screen.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'helpers/barra.dart';
import 'helpers/contraste.dart';

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

/// Lleva a la vista y toca, y deja asentar lo que se abra. Al centro y no al
/// borde: arriba quedaría bajo la barra de vidrio, que se lleva el toque.
Future<void> tocar(WidgetTester tester, Key llave) async {
  final f = find.byKey(llave);
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

class _Lugar extends UserLocationNotifier {
  void fijar(UserLocationState nuevo) => state = nuevo;
}

void main() {
  /// El contenido sigue blanco y la cabecera usa el gris de superficie
  /// apagada, con una división bajo el título (dueño, 2026-10-19).
  void exigeFondoBlanco(WidgetTester tester) {
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.surface,
        reason: 'el fondo de el buzón');
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.transparent,
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

  group('Buzon.enviar con queja (D18)', () {
    Future<Map<String, dynamic>> enviarQueja(DatosQueja queja,
        {String texto = ''}) async {
      late Map<String, dynamic> cuerpo;
      final buzon = Buzon(
        backend: () => 'http://x',
        cliente: MockClient((r) async {
          cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('', 201);
        }),
      );
      expect(await buzon.enviar(TipoReporte.queja, texto, queja: queja),
          EnvioReporte.recibido);
      return cuerpo;
    }

    test('los motivos son los del backend, en su orden y con su texto', () {
      expect(MotivoQueja.values.map((m) => m.clave), [
        'no_paro', 'iba_lleno', 'mal_trato', 'conduccion', 'otra_ruta',
        'estado_bus', 'otro', //
      ]);
      expect(MotivoQueja.values.map((m) => m.texto), [
        'No paró', 'Iba lleno', 'Mal trato', 'Conducción', 'Otra ruta',
        'Estado del bus', 'Otro', //
      ]);
    });

    test('solo el motivo: sin ruta, bus, lugar ni hora', () async {
      final cuerpo =
          await enviarQueja(const DatosQueja(motivo: MotivoQueja.noParo));
      expect(cuerpo['tipo'], 'queja');
      expect(cuerpo['motivo'], 'no_paro');
      expect(cuerpo['texto'], '');
      for (final campo in ['routeId', 'busId', 'celda', 'hora']) {
        expect(cuerpo.containsKey(campo), isFalse, reason: campo);
      }
    });

    test('sin permiso no manda la celda aunque haya ubicación', () async {
      final cuerpo = await enviarQueja(const DatosQueja(
        motivo: MotivoQueja.ibaLleno,
        routeId: 'R-1',
        ubicacion: (lat: 10.98712, lng: -74.81234),
        compartirLugar: false,
      ));
      expect(cuerpo.containsKey('celda'), isFalse);
      expect(cuerpo.toString(), isNot(contains('10.98')));
    });

    test('con permiso manda el centro de la celda de 150 m, no el punto',
        () async {
      final cuerpo = await enviarQueja(const DatosQueja(
        motivo: MotivoQueja.ibaLleno,
        routeId: 'R-1',
        ubicacion: (lat: 10.98712, lng: -74.81234),
        compartirLugar: true,
      ));
      final centro = centroCeldaBusqueda(10.98712, -74.81234);
      expect(cuerpo['celda'], {'lat': centro.lat, 'lng': centro.lng});
      expect(cuerpo.toString(), isNot(contains('10.98712')));
    });

    test('ruta, bus y la hora en punto, en UTC con zona', () async {
      final cuerpo = await enviarQueja(
        DatosQueja(
          motivo: MotivoQueja.conduccion,
          routeId: 'R-1',
          busId: 'BUS-ABC123',
          hora: DateTime.utc(2026, 11, 10, 18, 47, 12, 345, 678),
        ),
        texto: '  Frenaba duro ',
      );
      expect(cuerpo['routeId'], 'R-1');
      expect(cuerpo['busId'], 'BUS-ABC123');
      expect(cuerpo['hora'], '2026-11-10T18:00:00.000Z');
      expect(cuerpo['texto'], 'Frenaba duro');
    });

    test('el bus sin su ruta no se manda (el backend lo rechazaría)', () async {
      final cuerpo = await enviarQueja(
          const DatosQueja(motivo: MotivoQueja.otro, busId: 'BUS-ABC123'));
      expect(cuerpo.containsKey('busId'), isFalse);
    });

    test('un problema o una sugerencia no llevan campos de queja', () {
      final buzon = Buzon(
        backend: () => 'http://x',
        cliente: MockClient((_) async => http.Response('', 201)),
      );
      expect(
        () => buzon.enviar(TipoReporte.problema, 'abc',
            queja: const DatosQueja(motivo: MotivoQueja.otro)),
        throwsA(isA<AssertionError>()),
      );
      expect(() => buzon.enviar(TipoReporte.queja, ''),
          throwsA(isA<AssertionError>()));
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

    testWidgets('el buzón separa la cabecera en degradado del contenido blanco',
        (tester) async {
      await abrir(
          tester,
          Buzon(
            backend: () => 'http://x',
            cliente: MockClient((_) async => http.Response('', 201)),
          ));
      exigeFondoBlanco(tester);
      // Sin la trama de puntos (dueño, 2026-10-26); el grano de la
      // bienvenida en la parte blanca, no en la de color (dueño, 2026-10-27).
      expect(find.byType(FondoTexturizado), findsNothing);
      expect(find.byKey(const ValueKey('buzon-grano')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('buzon-cabecera')),
              matching: find.byType(Grano)),
          findsNothing);
      // «En vez de gris, un degradadito fino entre azul y verde» (dueño,
      // 2026-10-26).
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('buzon-cabecera')),
              matching: find.byType(DecoratedBox)),
          findsWidgets);
      const decoracion = CabeceraDegradada.decoracion;
      expect(decoracion.color, isNull);
      expect(
          (decoracion.gradient! as LinearGradient).colors,
          containsAllInOrder(
              [CabeceraDegradada.azul, CabeceraDegradada.verde]));
      // «Que no se note mucho, algo sutil» (dueño, 2026-10-19): media
      // línea de tinta al 8 %, más clara que el filo de las tarjetas.
      final raya = (decoracion.border! as Border).bottom;
      expect(raya.width, lessThanOrEqualTo(0.5));
      expect(raya.color.a, lessThanOrEqualTo(0.1));
    });

    // «Quiero como separadores que dividan las cosas, que se vea fino»
    // (dueño, 2026-10-19): tarjetas blancas planas, y la
    // nota de privacidad dentro de la del mensaje, bajo una raya de un
    // píxel, como una celda de Ajustes del iPhone.
    testWidgets(
        'las tarjetas llevan el filo de la app y la nota va fuera, sin raya',
        (tester) async {
      await abrir(
          tester,
          Buzon(
            backend: () => 'http://x',
            cliente: MockClient((_) async => http.Response('', 201)),
          ));
      final sugerencia = tester.widget<AnimatedContainer>(find
          .descendant(
              of: find.byKey(const ValueKey('buzon_sugerencia')),
              matching: find.byType(AnimatedContainer))
          .first);
      final deco = sugerencia.decoration! as BoxDecoration;
      expect(deco.color, Colors.white);
      expect(deco.boxShadow, isNull);
      expect((deco.border! as Border).top.color, AppColors.filo);

      final tarjeta = find.byKey(const ValueKey('buzon_tarjeta'));
      final caja =
          tester.widget<DecoratedBox>(tarjeta).decoration as BoxDecoration;
      expect(caja.color, Colors.white);
      expect(caja.boxShadow, isNull);
      final campo =
          tester.widget<TextField>(find.byKey(const ValueKey('buzon_texto')));
      expect(campo.decoration!.enabledBorder!.borderSide.color, AppColors.filo);
      expect(campo.decoration!.enabledBorder!.borderSide.width, 1);

      // Sin raya dentro del mensaje (dueño, 2026-10-19: no gustó): la nota
      // va fuera, bajo el campo.
      expect(find.byType(Divider), findsNothing);
      final nota = find.textContaining('No incluyas datos personales');
      await tester.scrollUntilVisible(nota, 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.descendant(of: tarjeta, matching: nota), findsNothing);
      expect(tester.getTopLeft(nota).dy,
          greaterThan(tester.getRect(tarjeta).bottom));
    });

    testWidgets('el formulario pasa bajo la barra de vidrio al subir',
        (tester) async {
      await abrir(
          tester,
          Buzon(
            backend: () => 'http://x',
            cliente: MockClient((_) async => http.Response('', 201)),
          ));
      await exigeBarraVidrio(
          tester,
          find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Text))
              .first);
    });

    // «En la parte de sugerencias todo parece igual y del mismo color»
    // (dueño, 2026-10-18): cada opción lleva su color también sin elegir,
    // el problema en coral y la sugerencia en ámbar, y la página se parte
    // en dos bloques con su título.
    testWidgets('cada opción tiene su color, elegida o no', (tester) async {
      await abrir(
          tester,
          Buzon(
            backend: () => 'http://x',
            cliente: MockClient((_) async => http.Response('', 201)),
          ));
      (Color, Color) circulo(String clave, IconData icono) {
        final ic = find.descendant(
            of: find.byKey(ValueKey(clave)), matching: find.byIcon(icono));
        final caja = tester.widget<AnimatedContainer>(find
            .ancestor(of: ic, matching: find.byType(AnimatedContainer))
            .first);
        return (
          (caja.decoration! as BoxDecoration).color!,
          tester.widget<Icon>(ic).color!,
        );
      }

      void exige(String clave, IconData icono, Color fondo, Color tinta) {
        final (f, t) = circulo(clave, icono);
        expect((f, t), (fondo, tinta), reason: clave);
        exigeContraste(contraste(t, f), 3, '$clave: ícono sobre su círculo');
      }

      const problema = ('buzon_problema', Icons.report_gmailerrorred_outlined);
      const sugerencia = ('buzon_sugerencia', Icons.lightbulb_outline_rounded);
      // Arranca en «Un problema».
      exige(problema.$1, problema.$2, AppColors.coralAccessible, Colors.white);
      exige(sugerencia.$1, sugerencia.$2, AppColors.warningLight,
          AppColors.warningAccessible);

      await tester.tap(find.byKey(const ValueKey('buzon_sugerencia')));
      await tester.pumpAndSettle();
      exige(problema.$1, problema.$2, AppColors.coralLight,
          AppColors.coralAccessible);
      exige(sugerencia.$1, sugerencia.$2, AppColors.warningAccessible,
          Colors.white);
    });

    testWidgets('las opciones y el campo llevan su título de sección',
        (tester) async {
      await abrir(
          tester,
          Buzon(
            backend: () => 'http://x',
            cliente: MockClient((_) async => http.Response('', 201)),
          ));
      double y(Finder f) => tester.getTopLeft(f).dy;
      for (final (titulo, debajo) in [
        ('Tipo de mensaje', find.byKey(const ValueKey('buzon_problema'))),
        ('Tu mensaje', find.byKey(const ValueKey('buzon_texto'))),
      ]) {
        final t = find.text(titulo);
        expect(find.ancestor(of: t, matching: find.byType(TituloSeccion)),
            findsOneWidget,
            reason: titulo);
        expect(y(t), lessThan(y(debajo)), reason: titulo);
      }
      expect(
          y(find.text('Tu mensaje')),
          greaterThan(tester
              .getRect(find.byKey(const ValueKey('buzon_problema')))
              .bottom));
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
          AppColors.textPrimary,
          reason:
              'el blanco sobre el verde #00A859 da 3,11:1, bajo el mínimo AA');
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

  // La queja (D18): sobre un bus o su conductor, con motivo y, si el
  // pasajero quiere, la ruta, el bus, la hora y la zona. La ve la empresa de
  // la ruta en su panel.
  group('BuzonScreen: la queja', () {
    const ruta =
        RouteInfo(id: 'R-72', name: 'B18 Tcherassi', companyId: 'EMP-01');
    const otra =
        RouteInfo(id: 'R-30', name: 'C16 Murillo', companyId: 'EMP-01');
    BusPosition bus(String id) => BusPosition(
          busId: id,
          routeId: ruta.id,
          lat: 10.98,
          lon: -74.81,
          heading: 0,
          speedKmh: 20,
          timestamp: DateTime.now(),
          isGhostBus: false,
        );

    late Map<String, dynamic> cuerpo;
    late int envios;

    Future<ProviderContainer> abrir(
      WidgetTester tester, {
      RouteInfo? elegida,
      UserLocationState lugar = const UserLocationState(),
      List<BusPosition>? buses,
    }) async {
      envios = 0;
      cuerpo = {};
      final ubicacion = _Lugar()..fijar(lugar);
      final container = ProviderContainer(overrides: [
        buzonProvider.overrideWithValue(Buzon(
          backend: () => 'http://x',
          cliente: MockClient((r) async {
            envios++;
            cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
            return http.Response('', 201);
          }),
        )),
        userLocationProvider.overrideWith((ref) => ubicacion),
        busPositionsSourceProvider.overrideWith((ref, routeId) =>
            Stream.value(buses ?? [bus('BUS-ABC123'), bus('BUS-XYZ789')])),
        companiesProvider.overrideWith(
            (ref) async => const [Company(id: 'EMP-01', name: 'Sobusa')]),
        routesByCompanyProvider.overrideWith((ref, id) async => [ruta, otra]),
      ]);
      addTearDown(container.dispose);
      if (elegida != null) {
        container.read(selectedRouteProvider.notifier).select(elegida);
      }
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BuzonScreen()),
      ));
      await tester.pumpAndSettle();
      await tocar(tester, const ValueKey('buzon_queja'));
      return container;
    }

    testWidgets('pide un motivo y deja el texto opcional', (tester) async {
      await abrir(tester, elegida: ruta);
      final enviar0 = find.byKey(const ValueKey('buzon_enviar'));
      expect(tester.widget<FilledButton>(enviar0).onPressed, isNull,
          reason: 'sin motivo no sale');
      for (final motivo in MotivoQueja.values) {
        expect(find.byKey(ValueKey('queja_motivo_${motivo.clave}')),
            findsOneWidget);
        expect(find.text(motivo.texto), findsOneWidget);
      }
      await tocar(tester, const ValueKey('queja_motivo_no_paro'));
      expect(tester.widget<FilledButton>(enviar0).onPressed, isNotNull,
          reason: 'el motivo basta: el texto es opcional');
      await tester.enterText(find.byKey(const ValueKey('buzon_texto')), 'ab');
      await tester.pump();
      expect(tester.widget<FilledButton>(enviar0).onPressed, isNull,
          reason: 'si escribe algo, que diga algo (3 o más)');
    });

    testWidgets('manda motivo, la ruta del mapa y la hora, sin zona',
        (tester) async {
      await abrir(tester,
          elegida: ruta,
          lugar: const UserLocationState(
              mode: UserLocationMode.gps, lat: 10.98712, lon: -74.81234));
      // La ruta que ya mira en el mapa viene puesta.
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('queja_ruta')),
              matching: find.text('Tcherassi')),
          findsOneWidget);
      await tocar(tester, const ValueKey('queja_motivo_iba_lleno'));
      await enviar(tester);
      await tester.pumpAndSettle();
      expect(envios, 1);
      expect(cuerpo['tipo'], 'queja');
      expect(cuerpo['motivo'], 'iba_lleno');
      expect(cuerpo['routeId'], 'R-72');
      expect(cuerpo.containsKey('busId'), isFalse);
      expect(cuerpo['hora'], matches(RegExp(r'T\d{2}:00:00\.000Z$')));
      expect(cuerpo.containsKey('celda'), isFalse,
          reason: 'la zona sale solo si el pasajero la comparte');
      expect(find.text('Gracias, lo recibimos'), findsOneWidget);
    });

    testWidgets('comparte la zona solo con el interruptor', (tester) async {
      await abrir(tester,
          elegida: ruta,
          lugar: const UserLocationState(
              mode: UserLocationMode.gps, lat: 10.98712, lon: -74.81234));
      final interruptor = find.byKey(const ValueKey('queja_lugar'));
      expect(tester.widget<Switch>(interruptor).value, isFalse);
      await tocar(tester, const ValueKey('queja_lugar'));
      await tocar(tester, const ValueKey('queja_motivo_conduccion'));
      await enviar(tester);
      await tester.pumpAndSettle();
      final celda = centroCeldaBusqueda(10.98712, -74.81234);
      expect(cuerpo['celda'], {'lat': celda.lat, 'lng': celda.lng});
    });

    testWidgets('sin punto en el mapa no hay zona que compartir',
        (tester) async {
      await abrir(tester, elegida: ruta);
      final interruptor = find.byKey(const ValueKey('queja_lugar'));
      await tester.ensureVisible(interruptor);
      expect(tester.widget<Switch>(interruptor).onChanged, isNull);
      expect(find.text('Pon tu punto en el mapa para compartirla.'),
          findsOneWidget);
    });

    testWidgets('elige el bus entre los de la ruta en línea', (tester) async {
      await abrir(tester, elegida: ruta);
      await tocar(tester, const ValueKey('queja_bus'));
      expect(
          find.byKey(const ValueKey('queja_bus_BUS-ABC123')), findsOneWidget);
      expect(find.text('XYZ789'), findsOneWidget);
      await tocar(tester, const ValueKey('queja_bus_BUS-XYZ789'));
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('queja_bus')),
              matching: find.text('XYZ789')),
          findsOneWidget);
      await tocar(tester, const ValueKey('queja_motivo_mal_trato'));
      await enviar(tester);
      await tester.pumpAndSettle();
      expect(cuerpo['busId'], 'BUS-XYZ789');
      expect(cuerpo['routeId'], 'R-72');
    });

    testWidgets('sin buses en línea lo dice', (tester) async {
      await abrir(tester, elegida: ruta, buses: const []);
      await tocar(tester, const ValueKey('queja_bus'));
      expect(find.text('No hay buses de esta ruta en línea ahora.'),
          findsOneWidget);
    });

    testWidgets('sin ruta, el bus espera y la ruta se elige en su hoja',
        (tester) async {
      await abrir(tester);
      expect(find.text('Elige la ruta'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('queja_bus')));
      expect(
          tester
              .getSemantics(find.byKey(const ValueKey('queja_bus')))
              .flagsCollection
              .isEnabled,
          Tristate.isFalse);
      await tocar(tester, const ValueKey('queja_ruta'));
      await tocar(tester, const ValueKey('queja_ruta_R-30'));
      await tocar(tester, const ValueKey('queja_motivo_otra_ruta'));
      await enviar(tester);
      await tester.pumpAndSettle();
      expect(cuerpo['routeId'], 'R-30');
    });

    testWidgets('cambiar de ruta suelta el bus elegido', (tester) async {
      await abrir(tester, elegida: ruta);
      await tocar(tester, const ValueKey('queja_bus'));
      await tocar(tester, const ValueKey('queja_bus_BUS-ABC123'));
      await tocar(tester, const ValueKey('queja_ruta'));
      await tocar(tester, const ValueKey('queja_ruta_R-30'));
      await tocar(tester, const ValueKey('queja_motivo_estado_bus'));
      await enviar(tester);
      await tester.pumpAndSettle();
      expect(cuerpo['routeId'], 'R-30');
      expect(cuerpo.containsKey('busId'), isFalse);
    });

    testWidgets('la nota dice quién la lee', (tester) async {
      await abrir(tester, elegida: ruta);
      expect(
          find.text('La leen el equipo de Ya Viene y la empresa de la ruta. '
              'No incluyas datos personales.'),
          findsOneWidget);
    });

    testWidgets('elige el día y la hora en sus ruedas', (tester) async {
      await abrir(tester, elegida: ruta);
      await tocar(tester, const ValueKey('queja_hora'));
      expect(find.byKey(const ValueKey('queja_hora_dia')), findsOneWidget);
      // Un paso arriba en la rueda del día: ayer.
      await tester.drag(
          find.byKey(const ValueKey('queja_hora_dia')), const Offset(0, -40));
      await tester.pumpAndSettle();
      await tocar(tester, const ValueKey('queja_hora_listo'));
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('queja_hora')),
              matching: find.textContaining('Ayer')),
          findsOneWidget);
      await tocar(tester, const ValueKey('queja_motivo_no_paro'));
      await enviar(tester);
      await tester.pumpAndSettle();
      final hora = DateTime.parse(cuerpo['hora'] as String);
      final dias = DateTime.now().difference(hora).inHours;
      expect(dias, inInclusiveRange(1, 47));
    });
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
