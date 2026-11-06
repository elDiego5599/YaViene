import 'dart:async';

import 'package:clock/clock.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/ocupacion_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/reportes_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/control_map.dart'
    show estiloMapaProvider;
import 'package:ya_viene_control/features/fleet/presentation/widgets/escala_calor.dart';
import 'package:ya_viene_core/core/models/route_trajectory.dart';
import 'package:ya_viene_core/core/providers/map_providers.dart';
import 'package:ya_viene_core/shared/widgets/carga_fantasma.dart';

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

// Un día fijo, de 5 a. m. a 11 p. m.: el más lleno, a las 6 p. m. con 90 %.
const _dia = <int?>[
  38, 82, 88, 61, 42, 24, 18, 47, 44, 19, //
  26, 53, 84, 90, 63, 41, 30, 20, 12,
];

const _celdas = [
  CeldaBusqueda(lat: 10.963, lng: -74.796, count: 5),
  CeldaBusqueda(lat: 10.97, lng: -74.8, count: 12),
];

/// La flota del panel, quieta: solo importa su catálogo de rutas, que
/// Reportes usa para ordenar sus píldoras como las de Flota.
class _Flota extends FleetNotifier {
  _Flota(super.ref, FleetState inicial)
    : super(api: FleetApi(baseUrl: 'http://localhost:3000')) {
    state = inicial;
  }

  void llegaCatalogo(List<FleetRoute> rutas) =>
      state = state.copyWith(routes: rutas, catalogoListo: true);
}

FleetRoute _catalogo(String id) =>
    FleetRoute(routeId: id, name: id, total: 1, online: 1);

Future<void> _montar(
  WidgetTester tester, {
  required Future<List<RutaBusquedas>> Function(int? hora) cargarRutas,
  Future<List<CeldaBusqueda>> Function(String routeId, int? hora)? cargarCalor,
  List<int?> Function(String routeId, PeriodoReporte periodo)? ocupacion,
  // Por defecto el catálogo ya respondió vacío (o falló): orden del ranking.
  FleetState flota = const FleetState(catalogoListo: true),
}) async {
  await tester.binding.setSurfaceSize(const Size(1500, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fleetProvider.overrideWith((ref) => _Flota(ref, flota)),
        reportesRutasProvider.overrideWith(
          (ref, args) => cargarRutas(args.hora),
        ),
        reportesCalorProvider.overrideWith(
          (ref, args) =>
              cargarCalor?.call(args.routeId, args.hora) ??
              Future.value(_celdas),
        ),
        ocupacionProvider.overrideWith(
          (ref, args) => ocupacion?.call(args.routeId, args.periodo) ?? _dia,
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
  // «Las búsquedas ruta-reportes se actualizan raro» (dueño, 2026-11-06):
  // con datos móviles los reportes llegaban antes que el catálogo de Flota;
  // las píldoras salían en el orden del ranking, con la primera elegida, y
  // al llegar el catálogo se reordenaban y la ruta elegida saltaba. Ahora
  // el fantasma se queda hasta tener los dos, y se pinta una sola vez.
  testWidgets('sin el catálogo de Flota no pinta píldoras que luego saltan', (
    tester,
  ) async {
    await _montar(
      tester,
      flota: const FleetState(),
      cargarRutas: (_) async => [
        _ruta('R1', 'C16 Ruta 1', 4820, 6),
        _ruta('R2', 'B18 Ruta 2', 40, 7),
        _ruta('R3', 'C12 Ruta 3', 3, 12),
      ],
    );
    // El fantasma late: no se calma, se avanza a mano.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('pildora-ruta-R1')), findsNothing);
    expect(find.bySemanticsLabel('Cargando reportes'), findsOneWidget);

    final flota =
        ProviderScope.containerOf(
              tester.element(find.byType(ReportesScreen)),
            ).read(fleetProvider.notifier)
            as _Flota;
    flota.llegaCatalogo([_catalogo('R3'), _catalogo('R2'), _catalogo('R1')]);
    await tester.pumpAndSettle();

    final x = [
      for (final id in ['R3', 'R2', 'R1'])
        tester.getTopLeft(find.byKey(ValueKey('pildora-ruta-$id'))).dx,
    ];
    expect(x[0], lessThan(x[1]));
    expect(x[1], lessThan(x[2]));
    expect(
      tester.getSemantics(find.byKey(const ValueKey('pildora-ruta-R3'))),
      isSemantics(isSelected: true, isButton: true),
    );
  });

  // «Igual que la flota: arriba todas las rutas y en el cuadro solo la
  // ruta tocada; por defecto, la primera» (dueño, 2026-10-27).
  testWidgets('arriba las rutas en píldoras; el cuadro, solo la elegida', (
    tester,
  ) async {
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

    expect(find.text('Rutas más buscadas'), findsNothing);
    expect(find.byKey(const ValueKey('fila-ruta-R1')), findsNothing);
    // Todas las rutas, en una fila sobre los dos paneles; sin catálogo de
    // Flota todavía, en el orden del ranking.
    final pildoras = [
      for (final id in ['R1', 'R2', 'R3', 'R4'])
        find.byKey(ValueKey('pildora-ruta-$id')),
    ];
    for (var i = 0; i < pildoras.length; i++) {
      expect(pildoras[i], findsOneWidget);
      if (i > 0) {
        expect(
          tester.getTopLeft(pildoras[i]).dx,
          greaterThan(tester.getTopLeft(pildoras[i - 1]).dx),
        );
      }
      expect(
        tester.getBottomLeft(pildoras[i]).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('ocupacion'))).dy),
      );
    }
    expect(
      tester.getSemantics(pildoras.first),
      isSemantics(isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(pildoras[1]),
      isSemantics(isSelected: false, isButton: true),
    );

    // El cuadro habla de una ruta: su cifra, su puesto y su hora pico.
    String texto(String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;
    expect(texto('busquedas-cifra'), '4.820');
    expect(texto('busquedas-puesto'), 'Puesto 1 de 4');
    expect(texto('busquedas-pico'), horaPicoLabel(6));
    expect(
      texto('busquedas-rango'),
      totalPeriodoLabel(PeriodoReporte.mes, DateTime.now()),
    );
    expect(find.byKey(const ValueKey('ruta-mapa-R1')), findsOneWidget);

    await tester.tap(pildoras[2]);
    await tester.pumpAndSettle();
    expect(texto('busquedas-cifra'), '3');
    expect(texto('busquedas-puesto'), 'Puesto 3 de 4');
    expect(texto('busquedas-pico'), horaPicoLabel(12));
    expect(find.byKey(const ValueKey('ruta-mapa-R3')), findsOneWidget);
    expect(tester.getSemantics(pildoras[2]), isSemantics(isSelected: true));
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

  testWidgets('una sola tira de horas, en el mapa, con su escala y el pico', (
    tester,
  ) async {
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

    Color? color(int h) =>
        (tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: find.byKey(ValueKey('hora-mapa-$h')),
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration
                as BoxDecoration?)
            ?.color;
    for (var h = 0; h < 24; h++) {
      expect(find.byKey(ValueKey('hora-mapa-$h')), findsOneWidget);
    }
    // El mismo idioma de color del calor: sin búsquedas en gris, el pico en
    // el rojo de la escala.
    expect(color(0), AppColors.border);
    expect(color(15), isNot(AppColors.border));
    expect(color(18), colorEnEscala(1));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('hora-mapa-18')),
        matching: find.byTooltip('6 p. m., 450 búsquedas'),
      ),
      findsOneWidget,
    );
    // El pico se marca con un punto sobre su barra, y el rótulo lo dice.
    final punto = tester.getCenter(
      find.byKey(const ValueKey('hora-mapa-pico')),
    );
    final barra = tester.getRect(find.byKey(const ValueKey('hora-mapa-18')));
    expect(punto.dx, inInclusiveRange(barra.left, barra.right));
    expect(punto.dy, lessThan(barra.top));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('hora-mapa-rotulo'))).data,
      'Hora pico 6 a 7 p. m.',
    );
    // «Escojo 30 días y la leyenda dice todo el día» (dueño, 2026-10-27):
    // la tira dice qué suma el mapa y entre qué fechas.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('mapa-rango'))).data,
      totalPeriodoLabel(PeriodoReporte.mes, DateTime.now()),
    );
    expect(find.text('Todo el día'), findsNothing);
    // La leyenda va en la misma tira.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('horas-mapa')),
        matching: find.byKey(const ValueKey('leyenda-calor')),
      ),
      findsOneWidget,
    );
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
    final filtro = find.byKey(const ValueKey('filtro-hora'));
    expect(
      find.descendant(of: filtro, matching: find.text('Todas las horas')),
      findsOneWidget,
    );
    await tester.tap(filtro);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('filtro-hora-todo')),
        matching: find.text('Todas las horas'),
      ),
      findsOneWidget,
    );
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
    expect(find.byKey(const ValueKey('pildora-ruta-R1')), findsOneWidget);
  });

  testWidgets('una ruta sin búsquedas no muestra franja pico', (tester) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R0', 'A1 Ruta cero', 0, null)],
      cargarCalor: (_, _) async => [],
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('busquedas-cifra'))).data,
      '0',
    );
    expect(find.byKey(const ValueKey('busquedas-pico')), findsNothing);
    expect(find.byKey(const ValueKey('ruta-mapa-R0')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('hora-mapa-rotulo'))).data,
      'Sin búsquedas',
    );
    expect(find.byKey(const ValueKey('hora-mapa-pico')), findsNothing);
  });

  testWidgets('ruta sin calor lo dice en una línea', (tester) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R1', 'C16 Ruta 1', 2, 0)],
      cargarCalor: (_, _) async => [],
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin zonas con 5 búsquedas o más'), findsOneWidget);
    expect(find.byKey(const ValueKey('ruta-mapa-R1')), findsOneWidget);
  });

  testWidgets('con pocas búsquedas dice cuántas hubo, y por hora solo esa', (
    tester,
  ) async {
    final porHora = List<int>.filled(24, 0)
      ..[7] = 4
      ..[12] = 3;
    await _montar(
      tester,
      cargarRutas: (_) async => [
        _ruta('R1', 'C16 Ruta 1', 7, 7, porHora: porHora),
      ],
      cargarCalor: (_, _) async => [],
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Hay 7 búsquedas, pero ninguna zona llega a 5'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('hora-mapa-12')));
    await tester.pumpAndSettle();
    expect(
      find.text('Hay 3 búsquedas, pero ninguna zona llega a 5'),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('mapa-rango'))).data,
      totalHoraLabel(
        PeriodoReporte.mes,
        DateTime.now(),
        hora: 12,
        busquedas: 3,
      ),
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
    expect(find.byKey(const ValueKey('capa-calor-R1')), findsOneWidget);
  });

  testWidgets('el calor siempre va pintado y la ruta solo con su botón', (
    tester,
  ) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R1', 'C16 Ruta 1', 2, 0)],
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('capa-calor-R1')), findsOneWidget);
    // La ruta arranca sin pintar; el botón la pone y la quita (dueño,
    // 2026-10-26).
    expect(find.byType(PolylineLayer), findsNothing);
    // Es una casilla al pie de la leyenda, bajo una raya (dueño,
    // 2026-10-27), no una píldora suelta en la esquina del mapa.
    final boton = find.byKey(const ValueKey('alternar-ruta'));
    expect(boton, findsOneWidget);
    final leyenda = find.byKey(const ValueKey('horas-mapa'));
    expect(find.descendant(of: leyenda, matching: boton), findsOneWidget);
    final raya = find.byKey(const ValueKey('separador-ruta'));
    expect(find.descendant(of: leyenda, matching: raya), findsOneWidget);
    expect(
      tester.getRect(raya).top,
      greaterThan(
        tester.getRect(find.byKey(const ValueKey('leyenda-calor'))).bottom,
      ),
    );
    expect(tester.getRect(boton).top, greaterThan(tester.getRect(raya).bottom));
    expect(tester.getSize(boton).height, greaterThanOrEqualTo(28));
    expect(find.text('Ver ruta'), findsOneWidget);
    expect(
      tester.getSemantics(boton),
      matchesSemantics(
        label: 'Ver ruta',
        hasCheckedState: true,
        isChecked: false,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.text('Ver ruta'), findsOneWidget);
    expect(find.text('Quitar ruta'), findsNothing);
    expect(
      tester.getSemantics(boton),
      matchesSemantics(
        label: 'Ver ruta',
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    // La ruta va debajo del calor y translúcida, para que el calor mande
    // (dueño, 2026-10-26).
    final capas = tester.widget<FlutterMap>(find.byType(FlutterMap)).children;
    final ruta = capas.indexWhere((c) => c is PolylineLayer);
    final calor = capas.indexWhere(
      (c) => c.key == const ValueKey('capa-calor-R1'),
    );
    expect(ruta, lessThan(calor));
    final lineas = (capas[ruta] as PolylineLayer).polylines;
    for (final l in lineas) {
      expect(l.color.a, lessThanOrEqualTo(0.5));
    }
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);

    expect(find.byKey(const ValueKey('leyenda-calor')), findsOneWidget);
    expect(find.text('Menos'), findsOneWidget);
    expect(find.text('Más'), findsOneWidget);
    expect(find.text('Solo por donde pasa'), findsNothing);
    // El dueño no le vio función (2026-10-26).
    expect(find.byKey(const ValueKey('alternar-calor')), findsNothing);
    expect(find.text('Quitar calor'), findsNothing);
  });

  testWidgets(
    'el periodo vuelve a cargar lista y mapa con su rango',
    (tester) => _aMitadDeMes(() async {
      final periodos = <PeriodoReporte>[];
      final periodosCalor = <PeriodoReporte>[];
      await tester.binding.setSurfaceSize(const Size(1500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fleetProvider.overrideWith(
              (ref) => _Flota(ref, const FleetState(catalogoListo: true)),
            ),
            reportesRutasProvider.overrideWith((ref, args) async {
              periodos.add(args.periodo);
              return [_ruta('R1', 'C16 Ruta 1', 2, 0)];
            }),
            reportesCalorProvider.overrideWith((ref, args) async {
              periodosCalor.add(args.periodo);
              return _celdas;
            }),
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
      await tester.pumpAndSettle();
      expect(periodos, [PeriodoReporte.mes]);
      // El periodo ya no se repite a la izquierda: se lee en los filtros.
      expect(find.text('Últimos 30 días'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('periodo-hoy')));
      await tester.pumpAndSettle();
      expect(periodos.last, PeriodoReporte.hoy);
      expect(periodosCalor.last, PeriodoReporte.hoy);

      await tester.tap(find.byKey(const ValueKey('periodo-semana')));
      await tester.pumpAndSettle();
      expect(periodos.last, PeriodoReporte.semana);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('mapa-rango'))).data,
        totalPeriodoLabel(PeriodoReporte.semana, clock.now()),
      );

      // «Fecha» abre el calendario del mes; tocar un día lo elige y cierra.
      final hoy = clock.now().toUtc().subtract(const Duration(hours: 5));
      const meses = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];
      final mes = meses[hoy.month - 1];
      expect(find.text('Fecha'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('periodo-dia')));
      await tester.pumpAndSettle();
      // Un cuadro que sale bajo los periodos, no una ventana con velo, y con
      // ancho para que el mes se lea holgado.
      final calendario = find.byKey(const ValueKey('calendario-dia'));
      expect(calendario, findsOneWidget);
      expect(find.byKey(const ValueKey('ventana')), findsNothing);
      expect(tester.getSize(calendario).width, greaterThanOrEqualTo(340));
      expect(
        tester.getTopLeft(calendario).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const ValueKey('periodo-dia'))).dy,
        ),
      );
      await tester.tap(
        find.descendant(of: calendario, matching: find.text('1')),
      );
      await tester.pumpAndSettle();
      expect(calendario, findsNothing);
      final primero = PeriodoReporte.delDia(DateTime(hoy.year, hoy.month));
      expect(periodos.last, primero);
      expect(periodosCalor.last, primero);
      expect(find.text('1 ${mes.substring(0, 3)}'), findsOneWidget);

      // Tocar fuera lo cierra y deja el día que estaba.
      await tester.tap(find.byKey(const ValueKey('periodo-dia')));
      await tester.pumpAndSettle();
      expect(calendario, findsOneWidget);
      await tester.tapAt(const Offset(5, 400));
      await tester.pumpAndSettle();
      expect(calendario, findsNothing);
      expect(periodos.last, primero);

      // El rango va en el mismo cuadro, en un cuadrito bajo el calendario:
      // se marca «Desde», el día tocado pasa solo al «Hasta» y, con los dos,
      // se aplica y se cierra (dueño, 2026-10-27). Nada de ventana ni APLICAR.
      expect(find.text('Rango'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('periodo-dia')));
      await tester.pumpAndSettle();
      final cuadro = find.byKey(const ValueKey('cuadro-rango'));
      expect(cuadro, findsOneWidget);
      expect(
        tester.getTopLeft(cuadro).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(calendario).dy),
      );
      expect(find.text('Elegir'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('rango-desde')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: calendario, matching: find.text('1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('rango-desde')),
          matching: find.text('1 ${mes.substring(0, 3)}'),
        ),
        findsOneWidget,
      );
      // Con solo el desde, nada se vuelve a pedir y el cuadro sigue abierto.
      expect(calendario, findsOneWidget);
      expect(periodos.last, primero);
      await tester.tap(
        find.descendant(of: calendario, matching: find.text('${hoy.day}')),
      );
      await tester.pumpAndSettle();
      final rango = PeriodoReporte.entre(
        DateTime(hoy.year, hoy.month),
        DateTime(hoy.year, hoy.month, hoy.day),
      );
      expect(calendario, findsNothing);
      expect(find.byKey(const ValueKey('ventana')), findsNothing);
      expect(periodos.last, rango);
      expect(periodosCalor.last, rango);
      // El rango queda escrito en el segmento de la fecha.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('periodo-dia')),
          matching: find.text(periodoLabel(rango)),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('mapa-rango'))).data,
        totalPeriodoLabel(rango, clock.now()),
      );

      // Al abrirlo otra vez trae el rango, y tocar un día sin marcar ningún
      // extremo vuelve a un día suelto.
      await tester.tap(find.byKey(const ValueKey('periodo-dia')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('rango-hasta')),
          matching: find.text(periodoLabel(PeriodoReporte.delDia(hoy))),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: calendario, matching: find.text('1')),
      );
      await tester.pumpAndSettle();
      // El día 1 ya se pidió antes: el segmento lo dice sin otra consulta.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('periodo-dia')),
          matching: find.text('1 ${mes.substring(0, 3)}'),
        ),
        findsOneWidget,
      );
    }),
  );

  // «Todos los lunes entre hoy y hace 2 meses»: los días van en el mismo
  // cuadrito del rango y, con el rango puesto, se aplican sin cerrarlo.
  testWidgets(
    'los días de la semana recortan el rango sin cerrar el cuadro',
    (tester) => _aMitadDeMes(() async {
      final periodos = <PeriodoReporte>[];
      final periodosCalor = <PeriodoReporte>[];
      await tester.binding.setSurfaceSize(const Size(1500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fleetProvider.overrideWith(
              (ref) => _Flota(ref, const FleetState(catalogoListo: true)),
            ),
            reportesRutasProvider.overrideWith((ref, args) async {
              periodos.add(args.periodo);
              return [_ruta('R1', 'C16 Ruta 1', 2, 0)];
            }),
            reportesCalorProvider.overrideWith((ref, args) async {
              periodosCalor.add(args.periodo);
              return _celdas;
            }),
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
      await tester.pumpAndSettle();
      final calendario = find.byKey(const ValueKey('calendario-dia'));
      Finder dia(int d) => find.byKey(ValueKey('dia-semana-$d'));
      Color? fondo(int d) =>
          (tester
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: dia(d),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color;
      Future<void> tocarDia(String n) async {
        await tester.tap(
          find.descendant(of: calendario, matching: find.text(n)),
        );
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const ValueKey('periodo-dia')));
      await tester.pumpAndSettle();
      final cuadro = find.byKey(const ValueKey('cuadro-rango'));
      for (var d = 1; d <= 7; d++) {
        expect(find.descendant(of: cuadro, matching: dia(d)), findsOneWidget);
        expect(fondo(d), AppColors.surface);
      }
      expect(find.text('Solo estos días'), findsOneWidget);
      expect(find.byKey(const ValueKey('dias-todos')), findsNothing);
      expect(find.byKey(const ValueKey('dias-sin-resultado')), findsNothing);

      // Sin rango todavía, el lunes espera: nada se pide y sigue abierto.
      final pedidos = periodos.length;
      await tester.tap(dia(DateTime.monday));
      await tester.pumpAndSettle();
      expect(periodos, hasLength(pedidos));
      expect(calendario, findsOneWidget);
      expect(fondo(DateTime.monday), AppColors.boton);
      expect(find.byKey(const ValueKey('dias-todos')), findsOneWidget);

      // Al completar el rango se lleva el lunes y cierra.
      await tester.tap(find.byKey(const ValueKey('rango-desde')));
      await tester.pumpAndSettle();
      await tocarDia('1');
      await tocarDia('15');
      final lunes = PeriodoReporte.entre(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 15),
        dias: {DateTime.monday},
      );
      expect(calendario, findsNothing);
      expect(periodos.last, lunes);
      expect(periodosCalor.last, lunes);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('periodo-dia')),
          matching: find.text(periodoLabel(lunes)),
        ),
        findsOneWidget,
      );

      // Con el rango puesto, cada día tocado se aplica y el cuadro sigue.
      await tester.tap(find.byKey(const ValueKey('periodo-dia')));
      await tester.pumpAndSettle();
      expect(fondo(DateTime.monday), AppColors.boton);
      await tester.tap(dia(DateTime.wednesday));
      await tester.pumpAndSettle();
      final lunesYMiercoles = PeriodoReporte.entre(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 15),
        dias: {DateTime.monday, DateTime.wednesday},
      );
      expect(calendario, findsOneWidget);
      expect(periodos.last, lunesYMiercoles);
      expect(periodosCalor.last, lunesYMiercoles);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('mapa-rango'))).data,
        totalPeriodoLabel(lunesYMiercoles, clock.now()),
      );

      // «Todos» vuelve a contar la semana entera.
      await tester.tap(find.byKey(const ValueKey('dias-todos')));
      await tester.pumpAndSettle();
      expect(
        periodos.last,
        PeriodoReporte.entre(DateTime(2026, 10, 1), DateTime(2026, 10, 15)),
      );
      expect(fondo(DateTime.monday), AppColors.surface);
      expect(find.byKey(const ValueKey('dias-todos')), findsNothing);

      // Del martes 13 al miércoles 14 no hay domingo: lo dice en el cuadro.
      await tester.tap(dia(DateTime.sunday));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rango-desde')));
      await tester.pumpAndSettle();
      await tocarDia('13');
      await tocarDia('14');
      expect(
        periodos.last,
        PeriodoReporte.entre(
          DateTime(2026, 10, 13),
          DateTime(2026, 10, 14),
          dias: {DateTime.sunday},
        ),
      );
      await tester.tap(find.byKey(const ValueKey('periodo-dia')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dias-sin-resultado')), findsOneWidget);
      expect(find.text('Ningún domingo cae en estas fechas'), findsOneWidget);
      await tester.tap(dia(DateTime.saturday));
      await tester.pumpAndSettle();
      expect(
        find.text('Ninguno de esos días cae en estas fechas'),
        findsOneWidget,
      );
    }),
  );

  testWidgets(
    'en el rango, el hasta no deja días antes del desde',
    (tester) => _aMitadDeMes(() async {
      await _montar(
        tester,
        cargarRutas: (_) async => [_ruta('R1', 'C16 Ruta 1', 2, 0)],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('periodo-dia')));
      await tester.pumpAndSettle();
      final picker = find.descendant(
        of: find.byKey(const ValueKey('calendario-dia')),
        matching: find.byType(CalendarDatePicker),
      );
      final hoy = clock.now().toUtc().subtract(const Duration(hours: 5));
      final ultimo = DateTime(hoy.year, hoy.month, hoy.day);
      // «Hasta» sin desde marca el desde: no tiene contra qué medirse.
      await tester.tap(find.byKey(const ValueKey('rango-hasta')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CalendarDatePicker>(picker).selectableDayPredicate,
        isNull,
      );
      await tester.tap(
        find.descendant(of: picker, matching: find.text('${hoy.day}')),
      );
      await tester.pumpAndSettle();
      final hasta = tester.widget<CalendarDatePicker>(picker);
      expect(hasta.initialDate, ultimo);
      final antes = ultimo.subtract(const Duration(days: 1));
      expect(hasta.selectableDayPredicate!(antes), isFalse);
      expect(hasta.selectableDayPredicate!(ultimo), isTrue);
    }),
  );

  testWidgets('las horas del mapa pintan esa hora y conservan la ruta', (
    tester,
  ) async {
    final horas = <int?>[];
    final calor = <(String, int?)>[];
    final porHora = List<int>.filled(24, 0)..[7] = 30;
    await _montar(
      tester,
      cargarRutas: (hora) async {
        horas.add(hora);
        return [
          _ruta('R1', 'C16 Ruta 1', 30, 7, porHora: porHora),
          _ruta('R2', 'B18 Ruta 2', 4, 7, porHora: porHora),
        ];
      },
      cargarCalor: (routeId, hora) async {
        calor.add((routeId, hora));
        return _celdas;
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pildora-ruta-R2')));
    await tester.pumpAndSettle();
    // Sin hora elegida, el rótulo dice el pico del día.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('hora-mapa-rotulo'))).data,
      'Hora pico 7 a 8 a. m.',
    );

    await tester.tap(find.byKey(const ValueKey('hora-mapa-7')));
    await tester.pumpAndSettle();
    expect(horas.last, 7);
    expect(calor.last, ('R2', 7));
    expect(find.text('7 a 8 a. m.'), findsWidgets);

    // Tocar la hora elegida vuelve al día entero (el día ya estaba en
    // caché: el rótulo vuelve al pico, sin otra carga).
    await tester.tap(find.byKey(const ValueKey('hora-mapa-7')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('hora-mapa-rotulo'))).data,
      'Hora pico 7 a 8 a. m.',
    );
    expect(find.byKey(const ValueKey('ruta-mapa-R2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hora-mapa-12')));
    await tester.pumpAndSettle();
    expect(calor.last, ('R2', 12));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('hora-mapa-todo')),
        matching: find.text('Todas las horas'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('hora-mapa-todo')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('hora-mapa-rotulo'))).data,
      'Hora pico 7 a 8 a. m.',
    );
    expect(find.byKey(const ValueKey('hora-mapa-todo')), findsNothing);
  });

  testWidgets('bajo el ranking va la ocupación, en la misma pantalla', (
    tester,
  ) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R1', 'C16 Ruta 1', 2, 0)],
    );
    await tester.pumpAndSettle();

    // Sin pestañas: la ocupación ocupa el lugar del resumen de todas las
    // rutas, debajo del ranking.
    expect(find.byKey(const ValueKey('pestana-ocupacion')), findsNothing);
    expect(find.byKey(const ValueKey('resumen-rutas')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('ocupacion'))).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const ValueKey('busquedas-cifra'))).dy,
      ),
    );
    // «Nadie sabe si es un promedio» (dueño, 2026-10-27): lo dice a la
    // vista, con sus buses y sus fechas, no en un globo.
    expect(find.text('Ocupación promedio'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('ocupacion-rango'))).data,
      promedioPeriodoLabel(PeriodoReporte.mes, DateTime.now(), buses: 0),
    );
    expect(find.text('Datos de ejemplo'), findsOneWidget);
    expect(find.byKey(const ValueKey('ocupacion-sin-camaras')), findsOneWidget);
    // «promedio de N buses» va en el globo de la ficha, no en la cabecera.
    expect(find.byKey(const ValueKey('ocupacion-buses')), findsNothing);
    // Una barra por hora de servicio, de 5 a. m. a 11 p. m.
    expect(find.byKey(const ValueKey('aforo-hora-4')), findsNothing);
    for (var h = 5; h <= 23; h++) {
      expect(find.byKey(ValueKey('aforo-hora-$h')), findsOneWidget);
    }
    // Arranca en la hora más llena; tocar otra barra cambia la cifra.
    String cifra() =>
        tester.widget<Text>(find.byKey(const ValueKey('aforo-cifra'))).data!;
    String estado() =>
        tester.widget<Text>(find.byKey(const ValueKey('aforo-estado'))).data!;
    // Sin el bus dibujado ni rótulos por barra: un eje de horas fijo, y cada
    // barra en la misma escala de color del mapa (dueño, 2026-10-26).
    expect(find.byKey(const ValueKey('aforo-bus')), findsNothing);
    final eje = find.byKey(const ValueKey('ocupacion-eje'));
    for (final h in ['5 a. m.', '11 a. m.', '5 p. m.', '11 p. m.']) {
      expect(find.descendant(of: eje, matching: find.text(h)), findsOneWidget);
    }
    Color? tinte(int h) =>
        (tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: find.byKey(ValueKey('aforo-hora-$h')),
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration
                as BoxDecoration?)
            ?.color;
    expect((cifra(), estado()), ('90 %', 'Lleno'));
    expect(tinte(18), colorEnEscala(0.9));
    expect(tinte(11), isNot(colorEnEscala(0.18)));
    await tester.tap(find.byKey(const ValueKey('aforo-hora-11')));
    await tester.pumpAndSettle();
    expect((cifra(), estado()), ('18 %', 'Vacío'));
    expect(tinte(11), colorEnEscala(0.18));
    await tester.tap(find.byKey(const ValueKey('aforo-hora-12')));
    await tester.pumpAndSettle();
    expect((cifra(), estado()), ('47 %', 'Medio'));
  });

  testWidgets('la ocupación sigue a la ruta y al periodo elegidos', (
    tester,
  ) async {
    final pedidos = <(String, PeriodoReporte)>[];
    await _montar(
      tester,
      cargarRutas: (_) async => [
        _ruta('R1', 'C16 Ruta 1', 9, 0),
        _ruta('R2', 'B18 Ruta 2', 4, 0),
      ],
      ocupacion: (routeId, periodo) {
        pedidos.add((routeId, periodo));
        // R2 en la semana: más llena a las 7 a. m.
        if (routeId == 'R2' && periodo == PeriodoReporte.semana) {
          return [for (var i = 0; i < 19; i++) i == 2 ? 71 : 30];
        }
        return _dia;
      },
    );
    await tester.pumpAndSettle();
    String cifra() =>
        tester.widget<Text>(find.byKey(const ValueKey('aforo-cifra'))).data!;
    expect(pedidos.last, ('R1', PeriodoReporte.mes));
    expect(cifra(), '90 %');

    await tester.tap(find.byKey(const ValueKey('pildora-ruta-R2')));
    await tester.pumpAndSettle();
    expect(pedidos.last, ('R2', PeriodoReporte.mes));

    await tester.tap(find.byKey(const ValueKey('periodo-semana')));
    await tester.pumpAndSettle();
    expect(pedidos.last, ('R2', PeriodoReporte.semana));
    // Lo nuevo arranca otra vez en su hora más llena.
    expect(cifra(), '71 %');
  });

  testWidgets('sin viajes en el periodo lo dice, y las horas no se tocan', (
    tester,
  ) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R1', 'C16 Ruta 1', 2, 0)],
      ocupacion: (_, _) => List<int?>.filled(19, null),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ocupacion-sin-viajes')), findsOneWidget);
    expect(find.byKey(const ValueKey('aforo-cifra')), findsNothing);
    expect(find.byKey(const ValueKey('aforo-hora-5')), findsOneWidget);
  });

  testWidgets('mientras carga, la lista y el mapa laten con su forma', (
    tester,
  ) async {
    final rutas = Completer<List<RutaBusquedas>>();
    final calor = Completer<List<CeldaBusqueda>>();
    await _montar(
      tester,
      cargarRutas: (_) => rutas.future,
      cargarCalor: (_, _) => calor.future,
    );
    await tester.pump();

    expect(find.byType(CargaFantasma), findsNWidgets(2));
    expect(find.bySemanticsLabel('Cargando reportes'), findsOneWidget);
    expect(find.bySemanticsLabel('Cargando el mapa'), findsOneWidget);
    expect(find.byKey(const ValueKey('fantasma-busquedas')), findsOneWidget);

    rutas.complete([_ruta('R1', 'C16 Ruta 1', 40, 6)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Llega la lista; el mapa de esa ruta sigue latiendo.
    expect(find.byKey(const ValueKey('pildora-ruta-R1')), findsOneWidget);
    expect(find.bySemanticsLabel('Cargando zonas de búsqueda'), findsOneWidget);

    calor.complete(_celdas);
    await tester.pumpAndSettle();
    expect(find.byType(CargaFantasma), findsNothing);
  });

  testWidgets('al cambiar la hora, el mapa de antes se queda atenuado', (
    tester,
  ) async {
    final rutas7 = Completer<List<RutaBusquedas>>();
    final calor7 = Completer<List<CeldaBusqueda>>();
    final porHora = List<int>.filled(24, 0)..[7] = 30;
    await _montar(
      tester,
      cargarRutas: (hora) => hora == 7
          ? rutas7.future
          : Future.value([_ruta('R1', 'C16 Ruta 1', 30, 7, porHora: porHora)]),
      cargarCalor: (_, hora) =>
          hora == 7 ? calor7.future : Future.value(_celdas),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hora-mapa-7')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Nada de fantasmas: lo de antes sigue, apagado, con su píldora.
    expect(find.byType(CargaFantasma), findsNothing);
    expect(find.byKey(const ValueKey('pildora-ruta-R1')), findsOneWidget);
    expect(find.byKey(const ValueKey('capa-calor-R1')), findsOneWidget);
    expect(find.byKey(const ValueKey('mapa-cargando')), findsOneWidget);

    rutas7.complete([_ruta('R1', 'C16 Ruta 1', 30, 7, porHora: porHora)]);
    calor7.complete(_celdas);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mapa-cargando')), findsNothing);
    expect(find.byKey(const ValueKey('capa-calor-R1')), findsOneWidget);
  });
}

/// El calendario de Reportes a mitad de mes: el día 1 no cabe un rango dentro
/// del mes a la vista y estas pruebas fallaban ese día.
Future<void> _aMitadDeMes(Future<void> Function() cuerpo) =>
    withClock(Clock.fixed(DateTime.utc(2026, 10, 15, 17)), cuerpo);
