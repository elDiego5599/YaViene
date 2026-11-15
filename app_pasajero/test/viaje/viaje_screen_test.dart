import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/providers/red_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/estilo_mapa_provider.dart';
import 'package:ya_viene_pasajero/features/viaje/planificador.dart';
import 'package:ya_viene_pasajero/features/viaje/viaje_screen.dart';

// Una calle recta de oeste a este por la latitud 11.
const _lat = 11.0;
GeoPoint _p(double metros, [double norte = 0]) =>
    GeoPoint(lat: _lat + norte / 110574, lon: -74.80 + metros / 109290);

Lugar _lugar(double metros, [double norte = 0]) =>
    Lugar(punto: _p(metros, norte), origen: OrigenLugar.pin);

final _origen = _lugar(450, 80);
final _destino = _lugar(2420, -60);

Viaje _viaje(String ruta, {double caminata = 80}) => Viaje(
      origen: _origen,
      destino: _destino,
      tramos: [
        TramoAPie(desde: _origen.punto, hasta: _p(450), metros: caminata),
        TramoEnBus(
          ruta: ruta,
          empresa: 'EMP-01',
          subida: PuntoDeRuta(
              ruta: ruta, avance: 450, punto: _p(450), caminata: caminata),
          bajada: PuntoDeRuta(
              ruta: ruta, avance: 2420, punto: _p(2420), caminata: 60),
          metrosPorLaRuta: 1970,
        ),
        TramoAPie(desde: _p(2420), hasta: _destino.punto, metros: 60),
      ],
    );

/// La pantalla sin mapa (el estilo nunca llega) y con el plan que se le dé:
/// lo que se prueba es lo que dice el panel en cada estado.
Future<void> _abrir(
  WidgetTester tester, {
  Lugar? origen,
  Lugar? destino,
  AsyncValue<Plan>? plan,
  bool hayRed = true,
  void Function()? alReintentar,
  Future<bool> Function(Viaje)? alIr,
}) async {
  // Un iPhone de 390 × 844 pt: el panel entero cabe, como en el teléfono.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      estiloMapaProvider.overrideWith((ref) => Completer<String>().future),
      hayRedProvider.overrideWith((ref) => Stream.value(hayRed)),
      planificadorProvider.overrideWith((ref) =>
          Planificador(Planificacion(origen: origen, destino: destino))),
      planProvider.overrideWith((ref) => plan),
      redDeRutasProvider.overrideWith((ref) {
        alReintentar?.call();
        return RedDeRutas(const []);
      }),
      rutasSobusaProvider.overrideWith((ref) async => const <RutaSobusa>[]),
      busQueVieneProvider.overrideWith((ref, tramo) => null),
      ritmoDeRutaProvider.overrideWith((ref, ruta) => null),
      if (alIr != null) irAlViajeProvider.overrideWithValue(alIr),
    ],
    child: const MaterialApp(home: ViajeScreen()),
  ));
  // La carga respira sin fin: se dejan pasar las entradas, sin esperar quietud.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('sin origen pide de dónde sale', (tester) async {
    await _abrir(tester);
    expect(find.byKey(const ValueKey('sin-origen')), findsOneWidget);
    expect(find.text('¿Desde dónde sales?'), findsOneWidget);
  });

  testWidgets('con origen y sin destino pide a dónde va', (tester) async {
    await _abrir(tester, origen: _origen);
    expect(find.byKey(const ValueKey('sin-destino')), findsOneWidget);
  });

  testWidgets('mientras se arma el plan, la carga', (tester) async {
    await _abrir(tester,
        origen: _origen, destino: _destino, plan: const AsyncLoading());
    expect(find.byKey(const ValueKey('cargando')), findsOneWidget);
  });

  testWidgets('si las rutas no cargan, Reintentar las vuelve a pedir',
      (tester) async {
    var pedidas = 0;
    await _abrir(
      tester,
      origen: _origen,
      destino: _destino,
      plan: AsyncError(Exception('sin red'), StackTrace.empty),
      alReintentar: () => pedidas++,
    );
    expect(find.byKey(const ValueKey('error')), findsOneWidget);
    // La red solo se arma si alguien la mira, como hace el mapa del panel.
    final contenedor =
        ProviderScope.containerOf(tester.element(find.byType(ViajeScreen)));
    final sub = contenedor.listen(redDeRutasProvider, (_, __) {});
    addTearDown(sub.close);
    final antes = pedidas;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(pedidas, greaterThan(antes));
  });

  testWidgets('muy cerca dice que se llega antes a pie', (tester) async {
    await _abrir(tester,
        origen: _origen,
        destino: _destino,
        plan: const AsyncData(PlanMuyCerca(300)));
    expect(find.byKey(const ValueKey('muy-cerca')), findsOneWidget);
    expect(find.text('Se llega antes a pie'), findsOneWidget);
  });

  testWidgets('sin ruta dice de qué lado sí hay rutas', (tester) async {
    await _abrir(tester,
        origen: _origen,
        destino: _destino,
        plan: const AsyncData(
            PlanSinRuta(pasaCercaDelOrigen: true, pasaCercaDelDestino: false)));
    expect(find.byKey(const ValueKey('sin-ruta')), findsOneWidget);
    expect(find.textContaining('cerca de donde sales'), findsOneWidget);
  });

  testWidgets('enseña hasta tres opciones y la tocada pasa a ser la elegida',
      (tester) async {
    await _abrir(tester,
        origen: _origen,
        destino: _destino,
        plan: AsyncData(PlanConViajes([
          for (final r in ['R-1', 'R-2', 'R-3', 'R-4']) _viaje(r),
        ])));
    expect(find.byKey(const ValueKey('opciones')), findsOneWidget);
    expect(find.byKey(const ValueKey('opcion-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('opcion-3')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('opcion-1')));
    await tester.pumpAndSettle();
    final contenedor =
        ProviderScope.containerOf(tester.element(find.byType(ViajeScreen)));
    expect(contenedor.read(planificadorProvider).elegida, 1);
  });

  testWidgets('Ir lleva la opción elegida al mapa', (tester) async {
    final idas = <Viaje>[];
    await _abrir(
      tester,
      origen: _origen,
      destino: _destino,
      plan: AsyncData(PlanConViajes([_viaje('R-1'), _viaje('R-2')])),
      alIr: (v) async {
        idas.add(v);
        return false;
      },
    );
    await tester.tap(find.byKey(const ValueKey('opcion-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('viaje-ir')));
    await tester.pump();
    expect(idas.single.enBus.single.ruta, 'R-2');
    // Si no se pudo abrir, lo dice y se queda.
    await tester.pumpAndSettle();
    expect(find.text('No se pudo abrir la ruta. Revisa tu conexión.'),
        findsOneWidget);
  });

  // AppTextStyles.boton trae su color: puesto en el Text tapaba el blanco
  // del botón y salía tinta sobre #1E56A8 (1,9:1).
  Color colorDe(WidgetTester tester, String texto) =>
      DefaultTextStyle.of(tester.element(find.text(texto)))
          .style
          .merge(tester.widget<Text>(find.text(texto)).style)
          .color!;

  testWidgets('la letra de Ir va en blanco sobre el azul', (tester) async {
    await _abrir(tester,
        origen: _origen,
        destino: _destino,
        plan: AsyncData(PlanConViajes([_viaje('R-1')])));
    expect(colorDe(tester, 'Ir'), Colors.white);
  });

  testWidgets('la letra de Reintentar va en blanco sobre el azul',
      (tester) async {
    await _abrir(tester,
        origen: _origen,
        destino: _destino,
        plan: AsyncError(Exception('sin red'), StackTrace.empty));
    expect(colorDe(tester, 'Reintentar'), Colors.white);
  });

  testWidgets('sin internet avisa que no se ven los buses en vivo',
      (tester) async {
    await _abrir(tester, origen: _origen, hayRed: false);
    expect(find.text('Sin internet: no se ven los buses en vivo.'),
        findsOneWidget);
  });
}
