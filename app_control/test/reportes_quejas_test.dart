import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/domain/queja_panel.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/ocupacion_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/quejas_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/reportes_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/control_map.dart'
    show estiloMapaProvider;
import 'package:ya_viene_control/features/fleet/presentation/widgets/pildoras_ruta.dart';
import 'package:ya_viene_core/core/models/route_trajectory.dart';
import 'package:ya_viene_core/core/providers/map_providers.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show MotivoQueja;

class _Flota extends FleetNotifier {
  _Flota(super.ref) : super(api: FleetApi(baseUrl: 'http://localhost:3000')) {
    state = const FleetState(
      catalogoListo: true,
      routes: [
        FleetRoute(routeId: 'R1', name: 'B18 Uno', total: 1, online: 1),
        FleetRoute(routeId: 'R2', name: 'C12 Dos', total: 1, online: 1),
      ],
    );
  }
}

typedef _Args = ({
  String? routeId,
  PeriodoReporte periodo,
  MotivoQueja? motivo,
});

QuejaPanel _queja(
  String id, {
  MotivoQueja? motivo = MotivoQueja.ibaLleno,
  String texto = 'Iba muy lleno',
  String? busId,
  ({double lat, double lng})? celda,
}) => QuejaPanel(
  id: id,
  motivo: motivo,
  texto: texto,
  routeId: 'R1',
  ruta: 'B18 Uno',
  busId: busId,
  celda: celda,
  hora: DateTime.utc(2026, 11, 10, 15),
  creado: DateTime.utc(2026, 11, 10, 16),
);

Future<List<_Args>> _montar(
  WidgetTester tester,
  FutureOr<ReporteQuejas> Function(_Args args) quejas,
) async {
  final pedidos = <_Args>[];
  await tester.binding.setSurfaceSize(const Size(1500, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fleetProvider.overrideWith((ref) => _Flota(ref)),
        reportesRutasProvider.overrideWith(
          (ref, args) async => [
            RutaBusquedas(
              id: 'R1',
              nombre: 'B18 Uno',
              total: 3,
              porHora: List<int>.filled(24, 0),
              horaPico: 6,
            ),
          ],
        ),
        reportesCalorProvider.overrideWith((ref, args) async => const []),
        ocupacionProvider.overrideWith((ref, args) => const <int?>[]),
        routeTrajectoryProvider.overrideWith(
          (ref, routeId) async => RouteTrajectory(
            routeId: routeId,
            routeName: 'Ruta',
            points: const [
              GeoPoint(lat: 10.96, lon: -74.8),
              GeoPoint(lat: 10.98, lon: -74.79),
            ],
          ),
        ),
        estiloMapaProvider.overrideWith((ref) async {
          throw StateError('El estilo no se necesita en esta prueba');
        }),
        quejasProvider.overrideWith((ref, args) {
          pedidos.add(args);
          return quejas(args);
        }),
      ],
      child: const MaterialApp(home: ReportesScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byKey(const ValueKey('modo-quejas')));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 500));
  return pedidos;
}

void main() {
  testWidgets(
    'lista cada queja con motivo, bus y texto, y dice que nadie la verificó',
    (tester) async {
      await _montar(
        tester,
        (_) => ReporteQuejas(
          quejas: [
            _queja('Q1', busId: 'B-7', texto: 'No se detuvo en la parada'),
            _queja('Q2', motivo: MotivoQueja.malTrato, texto: 'Fue grosero'),
          ],
          celdas: const [],
        ),
      );
      await tester.pumpAndSettle();

      // Literales blindados (inventario-estados.md, «Quejas»): la empresa
      // lee lo que dijo un pasajero, no un hecho.
      expect(find.text('Sin verificar'), findsOneWidget);
      expect(
        find.text('Lo cuenta el pasajero y nadie lo ha comprobado'),
        findsOneWidget,
      );
      expect(find.text('Iba lleno'), findsOneWidget);
      expect(find.text('Mal trato'), findsWidgets);
      expect(find.text('No se detuvo en la parada'), findsOneWidget);
      expect(find.text('B-7'), findsOneWidget);
      expect(find.text('2 quejas'), findsOneWidget);
    },
  );

  testWidgets('sin quejas dice que aún no hay en el periodo', (tester) async {
    await _montar(tester, (_) => ReporteQuejas.vacio);
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay quejas en este periodo'), findsOneWidget);
  });

  testWidgets('si falla la carga ofrece reintentar y lo vuelve a pedir', (
    tester,
  ) async {
    var falla = true;
    final pedidos = await _montar(tester, (_) {
      if (falla) throw Exception('sin red');
      return ReporteQuejas.vacio;
    });
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar las quejas'), findsOneWidget);
    expect(find.byKey(const ValueKey('reintentar-quejas')), findsOneWidget);
    falla = false;
    final antes = pedidos.length;
    await tester.tap(find.byKey(const ValueKey('reintentar-quejas')));
    await tester.pumpAndSettle();

    expect(pedidos.length, greaterThan(antes));
    expect(find.text('Aún no hay quejas en este periodo'), findsOneWidget);
  });

  testWidgets('elegir un motivo y una ruta cambia lo que se pide', (
    tester,
  ) async {
    final pedidos = await _montar(tester, (_) => ReporteQuejas.vacio);
    await tester.pumpAndSettle();
    expect(pedidos.last.routeId, isNull);
    expect(pedidos.last.motivo, isNull);

    await tester.tap(find.byKey(const ValueKey('filtro-motivo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filtro-motivo-mal_trato')));
    await tester.pumpAndSettle();
    expect(pedidos.last.motivo, MotivoQueja.malTrato);

    await tester.tap(find.byKey(const ValueKey('pildora-queja-R2')));
    await tester.pumpAndSettle();
    expect(pedidos.last.routeId, 'R2');
    expect(pedidos.last.motivo, MotivoQueja.malTrato);

    // Volver a todas no pide nada: ese reporte ya está cargado.
    final antes = pedidos.length;
    await tester.tap(find.byKey(const ValueKey('pildora-queja-todas')));
    await tester.pumpAndSettle();
    expect(pedidos.length, antes);
    expect(
      tester
          .widget<PildoraRuta>(
            find.byKey(const ValueKey('pildora-queja-todas')),
          )
          .active,
      isTrue,
    );
  });

  testWidgets('el mapa cuenta las quejas por celda, sin placa', (tester) async {
    await _montar(
      tester,
      (_) => const ReporteQuejas(
        quejas: [],
        celdas: [
          CeldaQueja(lat: 10.97, lng: -74.8, total: 7),
          CeldaQueja(lat: 10.965, lng: -74.795, total: 2),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('burbuja-queja-0')), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('el mapa sin celdas lo dice', (tester) async {
    await _montar(tester, (_) => ReporteQuejas.vacio);
    await tester.pumpAndSettle();

    expect(find.text('Ninguna queja trae lugar'), findsOneWidget);
  });
}
