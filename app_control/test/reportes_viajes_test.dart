import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/domain/viaje_panel.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/ocupacion_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/viajes_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/reportes_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/control_map.dart'
    show estiloMapaProvider;
import 'package:ya_viene_core/core/models/route_trajectory.dart';
import 'package:ya_viene_core/core/providers/map_providers.dart';

class _Flota extends FleetNotifier {
  _Flota(super.ref) : super(api: FleetApi(baseUrl: 'http://localhost:3000')) {
    state = const FleetState(
      catalogoListo: true,
      routes: [FleetRoute(routeId: 'R1', name: 'B18 Uno', total: 1, online: 1)],
    );
  }
}

typedef _Args = ({PeriodoReporte periodo, int? franja});

ParViaje _par(PuntoZona o, PuntoZona d, int total) =>
    ParViaje(origen: o, destino: d, total: total);

const _a = (lat: 10.9728, lng: -74.7946);
const _b = (lat: 10.9782, lng: -74.7891);
const _c = (lat: 10.9674, lng: -74.8001);

Future<List<_Args>> _montar(
  WidgetTester tester,
  FutureOr<ReporteViajes> Function(_Args args) viajes,
) async {
  final pedidos = <_Args>[];
  await tester.binding.setSurfaceSize(const Size(1500, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fleetProvider.overrideWith((ref) => _Flota(ref)),
        reportesRutasProvider.overrideWith((ref, args) async => const []),
        reportesCalorProvider.overrideWith((ref, args) async => const []),
        ocupacionProvider.overrideWith((ref, args) => const <int?>[]),
        routeTrajectoryProvider.overrideWith(
          (ref, routeId) async => RouteTrajectory(
            routeId: routeId,
            routeName: 'Ruta',
            points: const [],
          ),
        ),
        estiloMapaProvider.overrideWith((ref) async {
          throw StateError('El estilo no se necesita en esta prueba');
        }),
        viajesProvider.overrideWith((ref, args) {
          pedidos.add(args);
          return viajes(args);
        }),
      ],
      child: const MaterialApp(home: ReportesScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byKey(const ValueKey('modo-viajes')));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 500));
  return pedidos;
}

ReporteViajes _tres() =>
    ReporteViajes([_par(_a, _b, 12), _par(_b, _c, 7), _par(_c, _a, 5)]);

List<Polyline> _lineas(WidgetTester tester) =>
    tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines;

void main() {
  testWidgets('lista cada par como «A a B» con su total, de más a menos', (
    tester,
  ) async {
    await _montar(tester, (_) => _tres());
    await tester.pumpAndSettle();

    expect(find.text('Viajes buscados'), findsOneWidget);
    expect(find.text('24 viajes'), findsOneWidget);
    expect(find.byKey(const ValueKey('viaje-par-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('viaje-par-2')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('viaje-par-0')),
        matching: find.text('12'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('el mapa dibuja una línea por par y una letra por zona', (
    tester,
  ) async {
    await _montar(tester, (_) => _tres());
    await tester.pumpAndSettle();

    expect(_lineas(tester), hasLength(3));
    for (final letra in ['A', 'B', 'C']) {
      expect(find.byKey(ValueKey('zona-$letra')), findsOneWidget);
    }
  });

  testWidgets('un par dentro de una sola zona no dibuja línea', (tester) async {
    await _montar(
      tester,
      (_) => ReporteViajes([_par(_a, _a, 9), _par(_a, _b, 6)]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('viaje-par-0')), findsOneWidget);
    expect(_lineas(tester), hasLength(1));
  });

  testWidgets('tocar un par marca su línea en el mapa', (tester) async {
    await _montar(tester, (_) => _tres());
    await tester.pumpAndSettle();
    final antes = [for (final l in _lineas(tester)) l.color];
    expect(antes.toSet(), hasLength(1));

    await tester.tap(find.byKey(const ValueKey('viaje-par-1')));
    await tester.pumpAndSettle();
    final despues = [for (final l in _lineas(tester)) l.color];
    expect(despues.toSet(), hasLength(2));

    // Tocarlo otra vez lo suelta.
    await tester.tap(find.byKey(const ValueKey('viaje-par-1')));
    await tester.pumpAndSettle();
    expect({for (final l in _lineas(tester)) l.color}, hasLength(1));
  });

  testWidgets('el pie dice que solo salen pares de 5 o más en un día', (
    tester,
  ) async {
    await _montar(tester, (_) => _tres());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Solo salen los trayectos que 5 o más personas buscaron el mismo día',
      ),
      findsOneWidget,
    );
  });

  testWidgets('sin pares dice que aún no hay suficientes viajes', (
    tester,
  ) async {
    await _montar(tester, (_) => ReporteViajes.vacio);
    await tester.pumpAndSettle();

    expect(
      find.text('Aún no hay suficientes viajes para mostrar'),
      findsWidgets,
    );
    expect(find.byType(PolylineLayer), findsNothing);
  });

  testWidgets('si falla la carga ofrece reintentar y lo vuelve a pedir', (
    tester,
  ) async {
    var falla = true;
    final pedidos = await _montar(tester, (_) {
      if (falla) throw Exception('sin red');
      return ReporteViajes.vacio;
    });
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar los viajes'), findsOneWidget);
    falla = false;
    final antes = pedidos.length;
    await tester.tap(find.byKey(const ValueKey('reintentar-viajes')));
    await tester.pumpAndSettle();

    expect(pedidos.length, greaterThan(antes));
    expect(
      find.text('Aún no hay suficientes viajes para mostrar'),
      findsWidgets,
    );
  });

  testWidgets('elegir una franja cambia lo que se pide', (tester) async {
    final pedidos = await _montar(tester, (_) => ReporteViajes.vacio);
    await tester.pumpAndSettle();
    expect(pedidos.last.franja, isNull);

    await tester.tap(find.byKey(const ValueKey('filtro-franja')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filtro-franja-2')));
    await tester.pumpAndSettle();
    expect(pedidos.last.franja, 2);
    expect(find.text('6 a. m. a 9 a. m.'), findsOneWidget);

    // Volver a todo el día no pide nada: ese reporte ya está cargado.
    final antes = pedidos.length;
    await tester.tap(find.byKey(const ValueKey('filtro-franja')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filtro-franja-todo')));
    await tester.pumpAndSettle();
    expect(pedidos.length, antes);
    expect(find.text('Todo el día'), findsOneWidget);
  });
}
