import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/services/abrir_enlace.dart';
import 'package:ya_viene_pasajero/core/widgets/pildora_navegacion.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/map_constants.dart';
import 'package:ya_viene_pasajero/features/recarga/boton_recarga.dart';
import 'package:ya_viene_pasajero/features/recarga/ficha_punto_recarga.dart';
import 'package:ya_viene_pasajero/features/recarga/pildora_recarga.dart';
import 'package:ya_viene_pasajero/features/recarga/recarga_providers.dart';

import 'helpers/contraste.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

const _lat = 10.98;
const _lon = -74.78;

final _sibus = FuenteCitada(
  nombre: 'SIBUS, Área Metropolitana de Barranquilla',
  url: Uri.parse('https://sibusoficial.ambq.gov.co/'),
  fecha: DateTime.utc(2026, 11, 11),
);

/// Un punto a [dLat] grados al norte de la persona (0,001 son 111 m).
PuntoDeRecarga _punto(
  String id,
  double dLat, {
  Fuente? fuente,
  String nombre = 'DONDE TERESA # 1',
  String direccion = 'CLL 76 N 18C 19',
  String? horario,
  String? municipio = 'Soledad',
}) =>
    PuntoDeRecarga(
      id: id,
      nombre: nombre,
      lat: _lat + dLat,
      lon: _lon,
      direccion: direccion,
      municipio: municipio,
      horario: horario,
      fuente: fuente ?? _sibus,
    );

({ProviderContainer c, _TestUserLocation ubicacion}) _contenedor({
  Future<List<PuntoDeRecarga>> Function()? puntos,
  bool conPunto = true,
}) {
  final ubicacion = _TestUserLocation();
  if (conPunto) {
    ubicacion.set(const UserLocationState(
      mode: UserLocationMode.gps,
      lat: _lat,
      lon: _lon,
    ));
  }
  final c = ProviderContainer(overrides: [
    userLocationProvider.overrideWith((ref) => ubicacion),
    puntosRecargaProvider.overrideWith(
      (ref) => (puntos ?? () async => [_punto('cerca', 0.001)])(),
    ),
  ]);
  addTearDown(c.dispose);
  return (c: c, ubicacion: ubicacion);
}

Widget _app(ProviderContainer c, Widget hijo) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(home: Scaffold(body: Center(child: hijo))),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('el archivo de puntos', () {
    final puntos = leerPuntosDeRecarga(
      File('assets/data/puntos_recarga.json').readAsStringSync(),
    );

    test('se lee entero y cada punto cita la fuente del AMB', () {
      expect(puntos.length, greaterThan(1000));
      for (final p in puntos) {
        expect(p.fuente, _sibus, reason: p.id);
      }
    });

    test('todos caen dentro del mapa del pasajero', () {
      for (final p in puntos) {
        expect(
            p.lat,
            inInclusiveRange(
                MapConstants.areaSurLat, MapConstants.areaNorteLat),
            reason: p.id);
        expect(
            p.lon,
            inInclusiveRange(
                MapConstants.areaOesteLon, MapConstants.areaEsteLon),
            reason: p.id);
      }
    });
  });

  group('cómo se escriben', () {
    test('el nombre en tipo oración, con las siglas en mayúsculas', () {
      expect(nombreDelPunto('DONDE TERESA # 1'), 'Donde Teresa # 1');
      expect(
          nombreDelPunto('CLL 63 PROLON. MURILLO'), 'CLL 63 Prolon. Murillo');
      expect(nombreDelPunto('OLIMPICA CC MARBELLA'), 'Olimpica CC Marbella');
      expect(nombreDelPunto('CDA LA 38'), 'CDA la 38');
      expect(nombreDelPunto('TIENDA DE LA ESQUINA'), 'Tienda de la Esquina');
      expect(nombreDelPunto('LOCAL ZAPATOCA-CRA39'), 'Local Zapatoca-Cra39');
    });

    test('la fecha de la fuente, en palabras', () {
      expect(fechaDeLaFuente(DateTime.utc(2026, 11, 11)),
          '11 de noviembre de 2026');
      expect(fechaDeLaFuente(DateTime.utc(2027, 1, 3)), '3 de enero de 2027');
    });

    test('la píldora cuenta los puntos', () {
      expect(textoPuntosCerca(0), 'No hay puntos de recarga cerca');
      expect(textoPuntosCerca(1), '1 punto de recarga cerca de tu punto');
      expect(textoPuntosCerca(7), '7 puntos de recarga cerca de tu punto');
    });

    test('cómo llegar abre el mapa del teléfono, a pie', () {
      final p = _punto('a', 0.001);
      expect(
        enlaceComoLlegar(p, TargetPlatform.iOS).toString(),
        'https://maps.apple.com/?daddr=10.981,-74.78&dirflg=w',
      );
      expect(
        enlaceComoLlegar(p, TargetPlatform.android).toString(),
        'https://www.google.com/maps/dir/?api=1&destination=10.981,-74.78'
        '&travelmode=walking',
      );
    });
  });

  group('estadoRecargaProvider', () {
    test('apagada mientras nadie prende la capa', () async {
      final (:c, ubicacion: _) = _contenedor();
      await c.read(puntosRecargaProvider.future);
      expect(c.read(estadoRecargaProvider), isA<RecargaApagada>());
    });

    test('prendida, los de 1 km a la redonda del más cerca al más lejos',
        () async {
      final (:c, ubicacion: _) = _contenedor(
        puntos: () async => [
          _punto('lejos', 0.02),
          _punto('medio', 0.005),
          _punto('cerca', -0.001),
        ],
      );
      await c.read(puntosRecargaProvider.future);
      c.read(capaRecargaVisibleProvider.notifier).state = true;

      final estado = c.read(estadoRecargaProvider);
      expect(estado, isA<RecargaCerca>());
      expect((estado as RecargaCerca).cercanos.map((e) => e.punto.id),
          ['cerca', 'medio']);
    });

    test('sin nadie cerca, la lista vacía', () async {
      final (:c, ubicacion: _) =
          _contenedor(puntos: () async => [_punto('lejos', 0.02)]);
      await c.read(puntosRecargaProvider.future);
      c.read(capaRecargaVisibleProvider.notifier).state = true;

      expect((c.read(estadoRecargaProvider) as RecargaCerca).cercanos, isEmpty);
    });

    test('sin punto de la persona no hay cerca de qué', () async {
      final (:c, ubicacion: _) = _contenedor(conPunto: false);
      await c.read(puntosRecargaProvider.future);
      c.read(capaRecargaVisibleProvider.notifier).state = true;

      expect(c.read(estadoRecargaProvider), isA<RecargaSinPunto>());
    });

    test('mientras lee, cargando; si el archivo falla, error', () async {
      final (:c, ubicacion: _) = _contenedor(
        puntos: () async => throw const FormatException('roto'),
      );
      c.read(capaRecargaVisibleProvider.notifier).state = true;
      expect(c.read(estadoRecargaProvider), isA<RecargaCargando>());

      await expectLater(
          c.read(puntosRecargaProvider.future), throwsFormatException);
      expect(c.read(estadoRecargaProvider), isA<RecargaError>());
    });

    test('apagar la capa suelta el punto elegido', () {
      final (:c, ubicacion: _) = _contenedor();
      c.read(capaRecargaVisibleProvider.notifier).state = true;
      c.read(puntoRecargaElegidoProvider.notifier).state = _punto('a', 0);

      c.read(capaRecargaVisibleProvider.notifier).state = false;

      expect(c.read(puntoRecargaElegidoProvider), isNull);
    });
  });

  group('BotonRecarga', () {
    testWidgets('prende y apaga la capa, y lo dice', (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      c.read(mapPreparingProvider.notifier).state = false;
      await tester.pumpWidget(_app(c, const BotonRecarga()));
      final semantica = tester.ensureSemantics();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Puntos de recarga')),
        matchesSemantics(
          label: 'Puntos de recarga',
          isButton: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.byType(BotonRecarga));
      await tester.pumpAndSettle();
      expect(c.read(capaRecargaVisibleProvider), isTrue);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Puntos de recarga')),
        matchesSemantics(
          label: 'Puntos de recarga',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.byType(BotonRecarga));
      await tester.pumpAndSettle();
      expect(c.read(capaRecargaVisibleProvider), isFalse);
      semantica.dispose();
    });

    testWidgets('mide 48 pt, el toque mínimo de la guía de Apple',
        (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      c.read(mapPreparingProvider.notifier).state = false;
      await tester.pumpWidget(_app(c, const BotonRecarga()));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(BotonRecarga)), const Size(48, 48));
    });

    testWidgets('con el selector encima no se puede tocar', (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      c.read(mapPreparingProvider.notifier).state = false;
      c.read(routeSelectorOpenProvider.notifier).state = true;
      await tester.pumpWidget(_app(c, const BotonRecarga()));

      await tester.tap(find.byType(BotonRecarga), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(c.read(capaRecargaVisibleProvider), isFalse);
    });

    testWidgets('sin pin puesto no se ve ni se puede tocar', (tester) async {
      final (:c, ubicacion: _) = _contenedor(conPunto: false);
      c.read(mapPreparingProvider.notifier).state = false;
      await tester.pumpWidget(_app(c, const BotonRecarga()));
      await tester.pumpAndSettle();

      expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          0);
      await tester.tap(find.byType(BotonRecarga), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(c.read(capaRecargaVisibleProvider), isFalse);
    });

    testWidgets('con la capa prendida sigue a mano para poder apagarla',
        (tester) async {
      final (:c, ubicacion: _) = _contenedor(conPunto: false);
      c.read(mapPreparingProvider.notifier).state = false;
      c.read(capaRecargaVisibleProvider.notifier).state = true;
      await tester.pumpWidget(_app(c, const BotonRecarga()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BotonRecarga));
      await tester.pumpAndSettle();
      expect(c.read(capaRecargaVisibleProvider), isFalse);
    });
  });

  group('PildoraRecarga', () {
    Future<void> pinta(WidgetTester tester, ProviderContainer c) async {
      await tester.pumpWidget(_app(c, const PildoraRecarga()));
      await tester.pumpAndSettle();
    }

    testWidgets('apagada no dice nada', (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      await pinta(tester, c);
      expect(find.textContaining('recarga'), findsNothing);
    });

    testWidgets('prendida cuenta los de cerca', (tester) async {
      final (:c, ubicacion: _) = _contenedor(
        puntos: () async => [_punto('a', 0.001), _punto('b', 0.002)],
      );
      c.read(capaRecargaVisibleProvider.notifier).state = true;
      await pinta(tester, c);
      expect(
          find.text('2 puntos de recarga cerca de tu punto'), findsOneWidget);
    });

    testWidgets('sin ninguno, el estado vacío', (tester) async {
      final (:c, ubicacion: _) =
          _contenedor(puntos: () async => [_punto('lejos', 0.02)]);
      c.read(capaRecargaVisibleProvider.notifier).state = true;
      await pinta(tester, c);
      expect(find.text('No hay puntos de recarga cerca'), findsOneWidget);
    });

    testWidgets('si el archivo falla lo dice y deja reintentar',
        (tester) async {
      var intentos = 0;
      final (:c, ubicacion: _) = _contenedor(puntos: () async {
        intentos++;
        if (intentos == 1) throw const FormatException('roto');
        return [_punto('a', 0.001)];
      });
      c.read(capaRecargaVisibleProvider.notifier).state = true;
      await pinta(tester, c);
      expect(find.text('No se pudieron leer los puntos de recarga'),
          findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('1 punto de recarga cerca de tu punto'), findsOneWidget);
    });
  });

  group('FichaPuntoRecarga', () {
    Future<List<Uri>> pinta(
      WidgetTester tester,
      ProviderContainer c,
      PuntoDeRecarga p,
    ) async {
      final abiertos = <Uri>[];
      final conEnlace = ProviderContainer(
        parent: c,
        overrides: [
          abrirEnlaceProvider.overrideWithValue((uri) async {
            abiertos.add(uri);
            return true;
          }),
        ],
      );
      addTearDown(conEnlace.dispose);
      c.read(capaRecargaVisibleProvider.notifier).state = true;
      c.read(puntoRecargaElegidoProvider.notifier).state = p;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: conEnlace,
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [FichaPuntoRecarga()])),
        ),
      ));
      await tester.pumpAndSettle();
      return abiertos;
    }

    testWidgets('sin punto elegido no hay ficha', (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      await tester.pumpWidget(_app(c, const FichaPuntoRecarga()));
      expect(find.text('Cómo llegar'), findsNothing);
    });

    testWidgets('dice dónde, a cuánto y de dónde sale el dato', (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      await pinta(tester, c, _punto('a', 0.001));

      expect(find.text('Donde Teresa # 1'), findsOneWidget);
      expect(find.text('Clle 76 #18C-19, Soledad'), findsOneWidget);
      expect(find.text('Punto de recarga a 111 m de tu punto'), findsOneWidget);
      expect(
        find.text('Fuente: SIBUS, Área Metropolitana de Barranquilla, '
            'consultada el 11 de noviembre de 2026'),
        findsOneWidget,
      );
      expect(find.text('Ejemplo'), findsNothing);
      expect(find.textContaining('Horario'), findsNothing);
    });

    testWidgets('se apoya sobre la píldora de pestañas, sin taparla',
        (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      await pinta(tester, c, _punto('a', 0.001));

      final techoDeLaPildora =
          tester.view.physicalSize.height / tester.view.devicePixelRatio -
              PildoraNavegacion.hueco(EdgeInsets.zero) -
              PildoraNavegacion.alto;
      final fondoDeLaFicha = tester.getBottomLeft(find.byType(FilledButton)).dy;
      expect(fondoDeLaFicha, lessThan(techoDeLaPildora));
    });

    testWidgets('la dirección no grita: se escribe como dirección',
        (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      await pinta(
          tester, c, _punto('a', 0.001, direccion: 'CLL 63 PROLON. MURILLO'));
      expect(find.text('Clle 63 Prolon. Murillo, Soledad'), findsOneWidget);
    });

    testWidgets('el horario solo si la fuente lo da', (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      await pinta(
          tester, c, _punto('a', 0.001, horario: 'Lunes a sábado, 7 a 19'));
      expect(find.text('Horario: Lunes a sábado, 7 a 19'), findsOneWidget);
    });

    testWidgets('un punto de ejemplo lo dice con todas las letras',
        (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      await pinta(tester, c, _punto('a', 0.001, fuente: const FuenteEjemplo()));

      expect(find.text('Ejemplo'), findsOneWidget);
      expect(
        find.text('Punto de ejemplo, sin fuente: no es un lugar real'),
        findsOneWidget,
      );
      expect(find.textContaining('Fuente:'), findsNothing);
    });

    testWidgets('sin punto de la persona, sin distancia', (tester) async {
      final (:c, ubicacion: _) = _contenedor(conPunto: false);
      await pinta(tester, c, _punto('a', 0.001));
      expect(find.text('Punto de recarga'), findsOneWidget);
    });

    testWidgets('cómo llegar abre el mapa del teléfono', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final (:c, ubicacion: _) = _contenedor();
      final abiertos = await pinta(tester, c, _punto('a', 0.001));

      await tester.tap(find.text('Cómo llegar'));
      await tester.pump();
      expect(abiertos.single.host, 'maps.apple.com');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('la X la cierra', (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      await pinta(tester, c, _punto('a', 0.001));

      await tester.tap(find.bySemanticsLabel('Cerrar'));
      await tester.pumpAndSettle();
      expect(c.read(puntoRecargaElegidoProvider), isNull);
      expect(find.text('Cómo llegar'), findsNothing);
    });

    testWidgets('la letra se lee', (tester) async {
      final (:c, ubicacion: _) = _contenedor();
      await pinta(tester, c, _punto('a', 0.001, fuente: const FuenteEjemplo()));

      for (final (texto, fondo, minimo) in [
        ('Donde Teresa # 1', AppColors.surface, 4.5),
        ('Clle 76 #18C-19, Soledad', AppColors.surface, 4.5),
        ('Ejemplo', AppColors.warningLight, 4.5),
        ('Cómo llegar', AppColors.acento, 4.5),
      ]) {
        exigeContraste(
            contraste(letraDe(tester, find.text(texto)), fondo), minimo, texto);
      }
    });
  });
}
