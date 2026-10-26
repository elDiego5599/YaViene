import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/ocupacion_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/reportes_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/control_map.dart'
    show estiloMapaProvider;
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

Future<void> _montar(
  WidgetTester tester, {
  required Future<List<RutaBusquedas>> Function(int? hora) cargarRutas,
  Future<List<CeldaBusqueda>> Function(String routeId, int? hora)? cargarCalor,
  List<int?> Function(String routeId, PeriodoReporte periodo)? ocupacion,
}) async {
  await tester.binding.setSurfaceSize(const Size(1500, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
    // La ficha de la lista y la de la leyenda del mapa, que abre pintado.
    expect(find.text('C16'), findsNWidgets(2));
    expect(find.text('Ruta 1'), findsNWidgets(2));
    expect(find.text('4.820 búsquedas'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('fila-ruta-R1')),
        matching: find.text('6 a 7 a. m.'),
      ),
      findsOneWidget,
    );
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('celda-hora-R1-18')),
        matching: find.byTooltip('6 p. m., 450 búsquedas'),
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
    expect(find.byKey(const ValueKey('capa-calor-R1')), findsOneWidget);
  });

  testWidgets('el mapa siempre va pintado, sin botón para quitarlo', (
    tester,
  ) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [_ruta('R1', 'C16 Ruta 1', 2, 0)],
    );
    await tester.pumpAndSettle();

    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.byKey(const ValueKey('capa-calor-R1')), findsOneWidget);
    expect(find.byKey(const ValueKey('leyenda-calor')), findsOneWidget);
    expect(find.text('Solo por donde pasa'), findsOneWidget);
    expect(find.text('Más búsquedas'), findsOneWidget);
    // El dueño no le vio función (2026-10-26).
    expect(find.byKey(const ValueKey('alternar-calor')), findsNothing);
    expect(find.text('Quitar calor'), findsNothing);
  });

  testWidgets('el periodo vuelve a cargar lista y mapa con su rango', (
    tester,
  ) async {
    final periodos = <PeriodoReporte>[];
    final periodosCalor = <PeriodoReporte>[];
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
    expect(find.text('Últimos 30 días'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('periodo-hoy')));
    await tester.pumpAndSettle();
    expect(periodos.last, PeriodoReporte.hoy);
    expect(periodosCalor.last, PeriodoReporte.hoy);

    await tester.tap(find.byKey(const ValueKey('periodo-semana')));
    await tester.pumpAndSettle();
    expect(periodos.last, PeriodoReporte.semana);
    expect(find.text('Últimos 7 días'), findsOneWidget);

    // «Fecha» abre el calendario del mes; tocar un día lo elige y cierra.
    final hoy = DateTime.now().toUtc().subtract(const Duration(hours: 5));
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
    await tester.tap(find.descendant(of: calendario, matching: find.text('1')));
    await tester.pumpAndSettle();
    expect(calendario, findsNothing);
    final primero = PeriodoReporte.delDia(DateTime(hoy.year, hoy.month));
    expect(periodos.last, primero);
    expect(periodosCalor.last, primero);
    expect(find.text('1 de $mes'), findsOneWidget);
    expect(find.text('1 ${mes.substring(0, 3)}'), findsOneWidget);

    // Tocar fuera lo cierra y deja el día que estaba.
    await tester.tap(find.byKey(const ValueKey('periodo-dia')));
    await tester.pumpAndSettle();
    expect(calendario, findsOneWidget);
    await tester.tapAt(const Offset(5, 400));
    await tester.pumpAndSettle();
    expect(calendario, findsNothing);
    expect(periodos.last, primero);
  });

  testWidgets('la tira de 24 horas solo sale en la ruta elegida', (
    tester,
  ) async {
    await _montar(
      tester,
      cargarRutas: (_) async => [
        _ruta('R1', 'C16 Ruta 1', 40, 6),
        _ruta('R2', 'B18 Ruta 2', 20, 7),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('celda-hora-R1-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('celda-hora-R2-0')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('fila-ruta-R2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('celda-hora-R1-0')), findsNothing);
    expect(find.byKey(const ValueKey('celda-hora-R2-0')), findsOneWidget);
  });

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
    await tester.tap(find.byKey(const ValueKey('fila-ruta-R2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hora-mapa-7')));
    await tester.pumpAndSettle();
    expect(horas.last, 7);
    expect(calor.last, ('R2', 7));
    expect(find.text('7 a 8 a. m.'), findsWidgets);

    // Tocar la hora elegida vuelve al día entero (el día ya estaba en
    // caché: el rótulo lo dice, sin otra carga).
    await tester.tap(find.byKey(const ValueKey('hora-mapa-7')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('hora-mapa-rotulo'))).data,
      'Todo el día',
    );
    expect(find.byKey(const ValueKey('ruta-mapa-R2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hora-mapa-12')));
    await tester.pumpAndSettle();
    expect(calor.last, ('R2', 12));
    await tester.tap(find.byKey(const ValueKey('hora-mapa-todo')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('hora-mapa-rotulo'))).data,
      'Todo el día',
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
        tester.getBottomLeft(find.byKey(const ValueKey('fila-ruta-R1'))).dy,
      ),
    );
    expect(find.text('Ocupación'), findsOneWidget);
    expect(find.text('Datos de ejemplo'), findsOneWidget);
    expect(find.byKey(const ValueKey('ocupacion-sin-camaras')), findsOneWidget);
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
    // El bus dibujado lleva sus 12 puestos llenos según la cifra, y solo la
    // barra elegida dice su hora (las demás la dicen al pasarles el puntero).
    String bus() =>
        tester.getSemantics(find.byKey(const ValueKey('aforo-bus'))).label;
    Finder rotulo(int h) => find.descendant(
      of: find.byKey(ValueKey('aforo-hora-$h')),
      matching: find.text(h > 12 ? '${h - 12}' : '$h'),
    );
    expect((cifra(), estado()), ('90 %', 'Lleno'));
    expect(bus(), 'Bus con 11 de 12 puestos ocupados');
    expect(rotulo(18), findsOneWidget);
    expect(rotulo(11), findsNothing);
    await tester.tap(find.byKey(const ValueKey('aforo-hora-11')));
    await tester.pumpAndSettle();
    expect((cifra(), estado()), ('18 %', 'Vacío'));
    expect(bus(), 'Bus con 2 de 12 puestos ocupados');
    expect(rotulo(11), findsOneWidget);
    expect(rotulo(18), findsNothing);
    await tester.tap(find.byKey(const ValueKey('aforo-hora-12')));
    await tester.pumpAndSettle();
    expect((cifra(), estado()), ('47 %', 'Medio'));
    expect(bus(), 'Bus con 6 de 12 puestos ocupados');
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

    await tester.tap(find.byKey(const ValueKey('fila-ruta-R2')));
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
    expect(find.byKey(const ValueKey('fantasma-ruta-0')), findsOneWidget);

    rutas.complete([_ruta('R1', 'C16 Ruta 1', 40, 6)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Llega la lista; el mapa de esa ruta sigue latiendo.
    expect(find.byKey(const ValueKey('fila-ruta-R1')), findsOneWidget);
    expect(find.bySemanticsLabel('Cargando zonas de búsqueda'), findsOneWidget);

    calor.complete(_celdas);
    await tester.pumpAndSettle();
    expect(find.byType(CargaFantasma), findsNothing);
  });
}
