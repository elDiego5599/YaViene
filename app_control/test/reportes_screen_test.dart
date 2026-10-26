import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/reportes_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/control_map.dart'
    show estiloMapaProvider;
import 'package:ya_viene_core/core/models/route_trajectory.dart';
import 'package:ya_viene_core/core/providers/map_providers.dart';

RutaBusquedas _ruta(
  String id,
  String nombre,
  int total,
  int? pico, {
  List<int>? porHora,
}) => RutaBusquedas(
  id: id,
  nombre: nombre,
  total: total,
  porHora: porHora ?? List<int>.filled(24, 0),
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
    final horas = List<int>.filled(24, 0)..[6] = 4820;
    await _montar(
      tester,
      cargarRutas: (_) async => [
        _ruta('R2', 'B18 Ruta 2', 4, 23),
        _ruta('R1', 'C16 Ruta 1', 4820, 6, porHora: horas),
        _ruta('R3', 'C12 Ruta 3', 3, 12),
        _ruta('R4', 'A1 Ruta 4', 1, 0),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('fila-ruta-R1'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('fila-ruta-R2'))).dy,
      ),
    );
    expect(find.text('C16'), findsOneWidget);
    expect(find.text('Ruta 1'), findsNWidgets(2));
    expect(find.text('4.820 búsquedas'), findsOneWidget);
    expect(find.text('6 a 7 a. m.'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Puesto 1, ruta C16 Ruta 1, 4.820 búsquedas, hora pico 6 a 7 a. m.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pico-hora-R1-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('barra-ruta-R1')), findsOneWidget);
    expect(find.byKey(const ValueKey('fila-ruta-R1')), findsOneWidget);
  });

  testWidgets('la primera ruta del ranking queda elegida y carga su mapa', (
    tester,
  ) async {
    final rutasCalor = <String>[];
    await _montar(
      tester,
      cargarRutas: (_) async => [
        _ruta('R2', 'B18 Ruta 2', 4, 23),
        _ruta('R1', 'C16 Ruta 1', 12, 6),
      ],
      cargarCalor: (routeId, _) async {
        rutasCalor.add(routeId);
        return _celdas;
      },
    );
    await tester.pumpAndSettle();

    expect(rutasCalor, ['R1']);
    expect(find.byKey(const ValueKey('ruta-mapa-R1')), findsOneWidget);
    expect(find.text('Desde dónde te buscan'), findsOneWidget);
  });

  testWidgets('la tira tiene 24 celdas y marca la hora pico', (tester) async {
    final horas = List<int>.filled(24, 0)
      ..[15] = 112
      ..[18] = 450;
    await _montar(
      tester,
      cargarRutas: (_) async => [
        _ruta('R1', 'C16 Ruta 1', 562, 18, porHora: horas),
      ],
    );
    await tester.pumpAndSettle();

    for (var hora = 0; hora < 24; hora++) {
      expect(find.byKey(ValueKey('celda-hora-R1-$hora')), findsOneWidget);
    }
    final pico = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('pico-hora-R1-18')),
    );
    final decoration = pico.decoration as BoxDecoration;
    expect((decoration.border as Border).top.width, 2);

    DecoratedBox celda(int hora) => tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(ValueKey('celda-hora-R1-$hora')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final horaSinBusquedas = celda(0);
    final horaConBusquedas = celda(15);
    final horaMaxima = celda(18);
    expect(
      (horaSinBusquedas.decoration as BoxDecoration).color,
      AppColors.border,
    );
    expect(
      (horaSinBusquedas.decoration as BoxDecoration).color,
      isNot((horaConBusquedas.decoration as BoxDecoration).color),
    );
    expect(
      (horaMaxima.decoration as BoxDecoration).color,
      const Color(0xFFE24B4A),
    );
    expect(find.byTooltip('6 p. m., 450 búsquedas'), findsOneWidget);
  });

  testWidgets('cambiar hora vuelve a cargar el provider con ese filtro', (
    tester,
  ) async {
    final requestedHours = <int?>[];
    await _montar(
      tester,
      cargarRutas: (hour) async {
        requestedHours.add(hour);
        return [_ruta('R1', 'C16 Ruta 1', 2, 0)];
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filtro-hora')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filtro-hora-6')));
    await tester.pumpAndSettle();

    expect(requestedHours, contains(6));
  });

  testWidgets('muestra vacío y permite reintentar un error de la lista', (
    tester,
  ) async {
    await _montar(tester, cargarRutas: (_) async => []);
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay búsquedas en este periodo'), findsOneWidget);

    var falla = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await _montar(
      tester,
      cargarRutas: (_) async {
        if (falla) throw StateError('fallo de prueba');
        return [_ruta('R1', 'C16 Ruta 1', 2, 0)];
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudieron cargar los reportes'), findsOneWidget);
    falla = false;
    await tester.tap(find.byKey(const ValueKey('reintentar-lista')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fila-ruta-R1')), findsOneWidget);
  });

  testWidgets('una ruta sin búsquedas no muestra franja pico', (tester) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R0', 'A1 Ruta cero', 0, null)],
      cargarCalor: (_, _) async => [],
    );
    await tester.pumpAndSettle();

    expect(find.text('0 búsquedas'), findsOneWidget);
    expect(find.byKey(const ValueKey('pico-hora-R0-0')), findsNothing);
    expect(find.byKey(const ValueKey('ruta-mapa-R0')), findsOneWidget);
  });

  testWidgets('ruta sin calor explica el mínimo de cinco búsquedas', (
    tester,
  ) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R1', 'C16 Ruta 1', 2, 0)],
      cargarCalor: (_, _) async => [],
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Se muestran zonas con al menos 5 búsquedas'),
      findsOneWidget,
    );
  });

  testWidgets('el error del mapa permite reintentar la carga de calor', (
    tester,
  ) async {
    var falla = true;
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R1', 'C16 Ruta 1', 2, 0)],
      cargarCalor: (_, _) async {
        if (falla) throw StateError('fallo del mapa');
        return _celdas;
      },
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reintentar-calor')), findsOneWidget);
    falla = false;
    await tester.tap(find.byKey(const ValueKey('reintentar-calor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alternar-calor')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capa-calor-R1')), findsOneWidget);
  });

  testWidgets('el mapa abre sin pintar y el botón pinta y quita el calor', (
    tester,
  ) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R1', 'C16 Ruta 1', 2, 0)],
    );
    await tester.pumpAndSettle();

    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.byKey(const ValueKey('capa-calor-R1')), findsNothing);
    expect(find.byKey(const ValueKey('leyenda-calor')), findsNothing);
    expect(find.text('Pintar calor'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('alternar-calor')));
    await tester.pumpAndSettle();

    expect(find.text('Quitar calor'), findsOneWidget);
    expect(find.byKey(const ValueKey('capa-calor-R1')), findsOneWidget);
    expect(find.text('Todo el día'), findsNWidgets(2));
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.text('Menos búsquedas'), findsOneWidget);
    expect(find.text('Más búsquedas'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('alternar-calor')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capa-calor-R1')), findsNothing);
    expect(find.text('Menos búsquedas'), findsNothing);
  });
}
