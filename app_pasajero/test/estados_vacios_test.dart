import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/providers/red_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'location_status_chip.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'route_selector_sheet.dart';

/// Los estados de error y vacío del pasajero, mirados de una vez (T6.7 ·
/// inventario de estados vacíos y de error de los 3 productos).
///
/// Son los que se ven cuando algo falla o no hay datos: el selector sin
/// empresas, con las rutas caídas o con una empresa que aún no tiene
/// rutas, y la píldora de ubicación sin permiso o sin GPS. Existían con
/// texto y sin ninguna prueba de widget: si mañana se cambia un copy a
/// medias —o se pierde el `Reintentar`— no salía nada rojo.
///
/// El inventario completo vive en `inventario-estados.md` del workspace;
/// su espejo en los otros dos productos está en
/// `app_control/test/estados_vacios_test.dart` y
/// `YaVieneWeb/tests/estados-vacios.test.ts`.
/// Fija el estado de ubicación que la píldora debe pintar, sin GPS real.
class _UbicacionFija extends UserLocationNotifier {
  _UbicacionFija(UserLocationState inicial) {
    state = inicial;
  }
}

UserLocationState _estado(UserLocationMode modo) => UserLocationState(
      mode: modo,
      lat: modo == UserLocationMode.locating ? null : 10.99,
      lon: modo == UserLocationMode.locating ? null : -74.79,
      updatedAt: DateTime(2026),
    );

void main() {
  // ── Píldora de ubicación ────────────────────────────────────────────
  //
  // El mismo arnés de `test/golden/chips_golden_test.dart`, sin el oro:
  // allá se fotografía cada modo, aquí se afirman los textos y las
  // acciones que el usuario toca.
  Future<void> montarChip(
    WidgetTester tester,
    UserLocationMode modo,
  ) async {
    SharedPreferences.setMockInitialValues({'pin_drag_learned': true});
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _UbicacionFija(_estado(modo))),
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
    await tester.pump();
  }

  testWidgets(
      'sin permiso de ubicación: el texto lo dice y ofrece '
      'Reintentar', (tester) async {
    await montarChip(tester, UserLocationMode.denied);

    expect(find.text('Sin ubicación'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('ubicación bloqueada en Ajustes: ofrece Abrir los Ajustes',
      (tester) async {
    await montarChip(tester, UserLocationMode.permanentDenied);

    expect(find.text('Ubicación bloqueada en los Ajustes'), findsOneWidget);
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets(
      'permiso concedido pero el GPS no fija: dice el fallo y '
      'ofrece Reintentar', (tester) async {
    await montarChip(tester, UserLocationMode.gpsFailed);

    expect(find.text('No pudimos obtener tu ubicación'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  // ── Selector de empresa y ruta ──────────────────────────────────────
  //
  // El mismo arnés de `test/route_selector_hint_test.dart`: guía en
  // marcha, escucha de los providers autoDispose y apertura del diálogo.
  late ProviderContainer container;

  Future<void> abrir(
    WidgetTester tester,
    List<Override> extras,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final guide = MapGuideNotifier();
    await guide.initialize(
      hasLocation: true,
      locationSettled: true,
      hasRoute: false,
      hasSelectedBus: false,
      hasActiveAlert: false,
    );
    container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guide),
      ...extras,
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
  }

  testWidgets(
      'empresas caídas: el error dice su causa, Reintentar se ve '
      'trabajar y lo recupera', (tester) async {
    var intentos = 0;
    await abrir(tester, [
      companiesProvider.overrideWith((ref) async {
        intentos++;
        if (intentos == 1) throw const RespuestaFallida(502);
        // La red de verdad tarda: es el rato en que el intento se ve.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return [const Company(id: 'EMP-01', name: 'Sobusa')];
      }),
    ]);

    // El túnel contestó sin backend detrás: no es la conexión del
    // pasajero, y la fila lo dice en vez de un «Error» a secas.
    expect(find.text('Falla en el servidor'), findsOneWidget);
    expect(find.text('No cargaron las empresas'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('Reintentar')));
    await tester.pump();
    // El intento se ve: antes Riverpod dejaba el error puesto mientras
    // volvía a pedir y la fila no se movía (dueño, 2026-09-30).
    expect(find.text('Reintentando…'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(intentos, 2);
    expect(find.text('Falla en el servidor'), findsNothing);
    // El tile vuelve al suyo («Elegir empresa») y la lista, recién abierta,
    // sí trae la empresa que la segunda petición trajo.
    expect(find.text('Elegir empresa'), findsOneWidget);

    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    expect(find.text('Sobusa'), findsOneWidget);
  });

  testWidgets(
      'empresas sin red: lo dice, y al volver la red reintenta '
      'solo', (tester) async {
    var intentos = 0;
    final redes = StreamController<bool>();
    addTearDown(redes.close);
    await abrir(tester, [
      hayRedProvider.overrideWith((ref) => redes.stream),
      companiesProvider.overrideWith((ref) async {
        intentos++;
        if (intentos == 1) throw const SocketException('sin red');
        return [const Company(id: 'EMP-01', name: 'Sobusa')];
      }),
    ]);
    redes.add(false);
    await tester.pump();
    expect(find.text('Sin conexión'), findsOneWidget);

    redes.add(true);
    await tester.pumpAndSettle();
    expect(intentos, 2);
    expect(find.text('Elegir empresa'), findsOneWidget);
  });

  testWidgets(
      'rutas caídas: el error de la lista se ve con su '
      'Reintentar', (tester) async {
    await abrir(tester, [
      companiesProvider.overrideWith((ref) async => [
            const Company(id: 'EMP-01', name: 'Sobusa'),
          ]),
      routesByCompanyProvider('EMP-01')
          .overrideWith((ref) async => throw Exception('caída del backend')),
    ]);

    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sobusa'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ruta'));
    await tester.pumpAndSettle();

    expect(find.text('Falla en el servidor'), findsOneWidget);
    expect(find.textContaining('No cargaron las rutas'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('empresa sin rutas: lo dice en la lista', (tester) async {
    await abrir(tester, [
      companiesProvider.overrideWith((ref) async => [
            const Company(id: 'EMP-01', name: 'Sobusa'),
          ]),
      routesByCompanyProvider('EMP-01')
          .overrideWith((ref) async => <RouteInfo>[]),
    ]);

    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sobusa'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ruta'));
    await tester.pumpAndSettle();

    expect(find.text('Esta empresa no tiene rutas aún'), findsOneWidget);
  });
}
