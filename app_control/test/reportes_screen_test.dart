import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/reportes_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/control_map.dart'
    show estiloMapaProvider;
import 'package:ya_viene_core/core/models/route_trajectory.dart';
import 'package:ya_viene_core/core/providers/map_providers.dart';

RutaBusquedas _ruta(String id, String nombre, int total, int? pico) =>
    RutaBusquedas(
      id: id,
      nombre: nombre,
      total: total,
      porHora: List<int>.filled(24, 0),
      horaPico: pico,
    );

const _celdas = [
  CeldaBusqueda(lat: 10.963, lng: -74.796, count: 5),
  CeldaBusqueda(lat: 10.97, lng: -74.8, count: 12),
];

Future<void> _montar(
  WidgetTester tester, {
  required Future<List<RutaBusquedas>> Function(int? hora) cargarRutas,
  Future<List<CeldaBusqueda>> Function(String routeId, int? hora)? cargarCalor,
}) async {
  await tester.binding.setSurfaceSize(const Size(1500, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reportesRutasProvider.overrideWith((ref, hora) => cargarRutas(hora)),
        reportesCalorProvider.overrideWith(
          (ref, args) =>
              cargarCalor?.call(args.routeId, args.hora) ??
              Future.value(_celdas),
        ),
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
      ],
      child: const MaterialApp(home: ReportesScreen()),
    ),
  );
}

void main() {
  testWidgets('ordena rutas, muestra barras y la franja pico', (tester) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [
        _ruta('R2', 'Ruta 2', 4, 23),
        _ruta('R1', 'Ruta 1', 12, 6),
        _ruta('R3', 'Ruta 3', 3, 12),
        _ruta('R4', 'Ruta 4', 1, 0),
      ],
    );
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('Ruta 1'));
    final second = tester.getTopLeft(find.text('Ruta 2'));
    expect(first.dy, lessThan(second.dy));
    expect(find.text('6 a 7 a. m.'), findsOneWidget);
    expect(find.text('11 p. m. a 12 a. m.'), findsOneWidget);
    expect(find.text('12 p. m. a 1 p. m.'), findsOneWidget);
    expect(find.text('12 a. m. a 1 a. m.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
  });

  testWidgets('ruta sin búsquedas muestra cero y no inventa una franja', (
    tester,
  ) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R0', 'Ruta sin búsquedas', 0, null)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Ruta sin búsquedas'), findsOneWidget);
    expect(find.text('0 búsquedas'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('cambiar hora vuelve a cargar el provider con ese filtro', (
    tester,
  ) async {
    final requestedHours = <int?>[];
    await _montar(
      tester,
      cargarRutas: (hour) async {
        requestedHours.add(hour);
        return [_ruta('R1', 'Ruta 1', 2, 0)];
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filtro-hora')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 a. m.').last);
    await tester.pumpAndSettle();
    expect(requestedHours, contains(6));
  });

  testWidgets('muestra vacío y permite reintentar un error', (tester) async {
    await _montar(tester, cargarRutas: (_) async => []);
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay búsquedas en este periodo'), findsOneWidget);

    var falla = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await _montar(
      tester,
      cargarRutas: (_) async {
        if (falla) throw StateError('fallo de prueba');
        return [_ruta('R1', 'Ruta 1', 2, 0)];
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudieron cargar los reportes'), findsOneWidget);
    falla = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Ruta 1'), findsOneWidget);
  });

  testWidgets('ruta sin calor explica el mínimo de cinco búsquedas', (
    tester,
  ) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R1', 'Ruta 1', 2, 0)],
      cargarCalor: (_, _) async => [],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruta 1'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Se muestran zonas con al menos 5 búsquedas'),
      findsOneWidget,
    );
  });

  testWidgets('el error al cargar calor permite reintentar', (tester) async {
    var falla = true;
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R1', 'Ruta 1', 2, 0)],
      cargarCalor: (_, _) async {
        if (falla) throw StateError('fallo del mapa');
        return _celdas;
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruta 1'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudieron cargar los reportes'), findsOneWidget);
    falla = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(CircleLayer), findsOneWidget);
  });

  testWidgets('el mapa recibe y pinta las celdas y el recorrido', (
    tester,
  ) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R1', 'Ruta 1', 2, 0)],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruta 1'));
    await tester.pumpAndSettle();
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(
      tester.widget<CircleLayer>(find.byType(CircleLayer)).circles,
      hasLength(2),
    );
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.text('Menos búsquedas'), findsOneWidget);
    expect(find.text('Más búsquedas'), findsOneWidget);
  });
}
