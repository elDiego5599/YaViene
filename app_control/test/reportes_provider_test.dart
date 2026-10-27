import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

class _Api extends FleetApi {
  _Api() : super(baseUrl: 'https://panel.test');
  int? horaRutas;
  int? horaCalor;
  String? rutaCalor;
  DateTime? desdeRutas;
  DateTime? desdeCalor;

  @override
  Future<Map<String, dynamic>> fetchSearchReports(
    String? token, {
    required DateTime desde,
    required DateTime hasta,
    int? hora,
  }) async {
    horaRutas = hora;
    desdeRutas = desde;
    return {
      'rutas': [_route('R2', 'Ruta 2', 4, 6), _route('R1', 'Ruta 1', 12, 6)],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchSearchHeatmap(
    String? token, {
    required String routeId,
    required DateTime desde,
    required DateTime hasta,
    int? hora,
  }) async {
    rutaCalor = routeId;
    desdeCalor = desde;
    horaCalor = hora;
    return {
      'routeId': routeId,
      'celdas': [
        {'lat': 11.0, 'lng': -74.8, 'count': 5},
      ],
    };
  }

  Map<String, Object> _route(String id, String name, int total, int peak) => {
    'routeId': id,
    'name': name,
    'total': total,
    'porHora': List<int>.filled(24, 0),
    'horaPico': peak,
  };
}

void main() {
  test('rangoPeriodo usa medianoche de Bogotá y ventanas móviles', () {
    final ahora = DateTime.utc(2026, 10, 26, 3);
    expect(
      rangoPeriodo(PeriodoReporte.hoy, ahora).$1,
      DateTime.utc(2026, 10, 25, 5),
    );
    expect(rangoPeriodo(PeriodoReporte.hoy, ahora).$2, ahora);
    expect(
      rangoPeriodo(PeriodoReporte.semana, ahora).$1,
      ahora.subtract(const Duration(days: 7)),
    );
    expect(
      rangoPeriodo(PeriodoReporte.mes, ahora).$1,
      ahora.subtract(const Duration(days: 30)),
    );
    expect(periodoLabel(PeriodoReporte.hoy), 'Hoy');
    expect(periodoLabel(PeriodoReporte.semana), '7 días');
    expect(periodoLabel(PeriodoReporte.mes), '30 días');
  });

  test('un día del calendario va de medianoche a medianoche de Bogotá', () {
    final ahora = DateTime.utc(2026, 10, 26, 20);
    final dia = PeriodoReporte.delDia(DateTime(2026, 10, 24, 15));
    expect(dia, PeriodoReporte.delDia(DateTime(2026, 10, 24)));
    expect(dia, isNot(PeriodoReporte.delDia(DateTime(2026, 10, 23))));
    expect(rangoPeriodo(dia, ahora), (
      DateTime.utc(2026, 10, 24, 5),
      DateTime.utc(2026, 10, 25, 5),
    ));
    // El día de hoy corta en este momento, no en la medianoche que viene.
    expect(rangoPeriodo(PeriodoReporte.delDia(DateTime(2026, 10, 26)), ahora), (
      DateTime.utc(2026, 10, 26, 5),
      ahora,
    ));
    expect(periodoLabel(dia), '24 oct');
  });

  late ProviderContainer container;
  late _Api api;

  setUp(() {
    api = _Api();
    container = ProviderContainer(
      overrides: [
        backendUrlProvider.overrideWith(
          () => BackendUrl.fija('https://panel.test'),
        ),
        fleetApiProvider.overrideWithValue(api),
      ],
    );
    container.read(authProvider.notifier).state = const AuthState(
      status: AuthStatus.authenticated,
      session: AuthSession(
        token: 'session-token',
        companyId: 'EMP-1',
        companyName: 'Empresa',
      ),
    );
  });

  tearDown(() => container.dispose());

  test(
    'providers ordenan rutas y pasan hora y ruta al cliente del panel',
    () async {
      final routes = await container.read(
        reportesRutasProvider((periodo: PeriodoReporte.mes, hora: 8)).future,
      );
      expect(routes.map((route) => route.id), ['R1', 'R2']);
      expect(api.horaRutas, 8);
      expect(DateTime.now().toUtc().difference(api.desdeRutas!).inDays, 30);
      await container.read(
        reportesRutasProvider((
          periodo: PeriodoReporte.semana,
          hora: null,
        )).future,
      );
      expect(DateTime.now().toUtc().difference(api.desdeRutas!).inDays, 7);

      final cells = await container.read(
        reportesCalorProvider((
          routeId: 'R2',
          periodo: PeriodoReporte.semana,
          hora: 8,
        )).future,
      );
      expect(api.rutaCalor, 'R2');
      expect(DateTime.now().toUtc().difference(api.desdeCalor!).inDays, 7);
      expect(api.horaCalor, 8);
      expect(cells.single.count, 5);
    },
  );

  test('franjas de hora pico usan formato colombiano de 12 horas', () {
    expect(horaPicoLabel(6), '6 a 7 a. m.');
    expect(horaPicoLabel(12), '12 p. m. a 1 p. m.');
    expect(horaPicoLabel(0), '12 a. m. a 1 a. m.');
    expect(horaPicoLabel(23), '11 p. m. a 12 a. m.');
  });

  test('una ruta sin búsquedas conserva horaPico nulo desde el contrato', () {
    final ruta = RutaBusquedas.fromJson({
      'routeId': 'R0',
      'name': 'Ruta sin búsquedas',
      'total': 0,
      'porHora': List<int>.filled(24, 0),
      'horaPico': null,
    });

    expect(ruta.horaPico, isNull);
  });

  // «Escojo 30 días y la leyenda dice todo el día» (dueño, 2026-10-27): el
  // mapa y la ocupación dicen qué cuentan y entre qué fechas, en Bogotá.
  group('rango del periodo en palabras', () {
    final ahora = DateTime.utc(2026, 10, 27, 20); // 3 p. m. en Bogotá

    test('fechas exactas del periodo', () {
      expect(rangoFechasLabel(PeriodoReporte.mes, ahora), '27 sep a 27 oct');
      expect(rangoFechasLabel(PeriodoReporte.semana, ahora), '20 a 27 oct');
      expect(rangoFechasLabel(PeriodoReporte.hoy, ahora), '27 oct');
      expect(
        rangoFechasLabel(PeriodoReporte.delDia(DateTime(2026, 10, 12)), ahora),
        '12 oct',
      );
    });

    test('a primera hora de Bogotá, hoy sigue siendo hoy', () {
      // 0:30 a. m. del 27 en Bogotá son las 5:30 UTC.
      final temprano = DateTime.utc(2026, 10, 27, 5, 30);
      expect(rangoFechasLabel(PeriodoReporte.hoy, temprano), '27 oct');
    });

    test('el año solo sale cuando no es el de ahora', () {
      final enero = DateTime.utc(2027, 1, 10, 20);
      expect(
        rangoFechasLabel(PeriodoReporte.mes, enero),
        '11 dic 2026 a 10 ene',
      );
      expect(
        rangoFechasLabel(PeriodoReporte.delDia(DateTime(2026, 12, 31)), enero),
        '31 dic 2026',
      );
    });

    test('el mapa dice que suma las búsquedas del periodo', () {
      expect(
        totalPeriodoLabel(PeriodoReporte.mes, ahora),
        'Total de los 30 días, 27 sep a 27 oct',
      );
      expect(
        totalPeriodoLabel(PeriodoReporte.semana, ahora),
        'Total de los 7 días, 20 a 27 oct',
      );
      expect(
        totalPeriodoLabel(PeriodoReporte.hoy, ahora),
        'Total de hoy, 27 oct',
      );
      expect(
        totalPeriodoLabel(PeriodoReporte.delDia(DateTime(2026, 10, 12)), ahora),
        'Total del 12 oct',
      );
    });

    test('la ocupación dice que promedia sus buses en el periodo', () {
      expect(
        promedioPeriodoLabel(PeriodoReporte.mes, ahora, buses: 3),
        'Promedio de 3 buses en los 30 días, 27 sep a 27 oct',
      );
      expect(
        promedioPeriodoLabel(PeriodoReporte.semana, ahora, buses: 1),
        'De 1 bus en los 7 días, 20 a 27 oct',
      );
      expect(
        promedioPeriodoLabel(PeriodoReporte.hoy, ahora, buses: 2),
        'Promedio de 2 buses hoy, 27 oct',
      );
      expect(
        promedioPeriodoLabel(
          PeriodoReporte.delDia(DateTime(2026, 10, 12)),
          ahora,
          buses: 2,
        ),
        'Promedio de 2 buses el 12 oct',
      );
      expect(
        promedioPeriodoLabel(PeriodoReporte.mes, ahora, buses: 0),
        'Esta ruta aún no tiene buses',
      );
    });
  });

  // «Igual que la flota» (dueño, 2026-10-27): las píldoras van en el orden
  // del catálogo de Flota, no en el del ranking.
  test('las rutas siguen el orden de Flota; las que no están, al final', () {
    RutaBusquedas r(String id, int total) => RutaBusquedas(
      id: id,
      nombre: id,
      total: total,
      porHora: List<int>.filled(24, 0),
      horaPico: null,
    );
    final rutas = [r('R3', 9), r('X', 8), r('R1', 5), r('Y', 4), r('R2', 1)];
    expect(ordenarComoFlota(rutas, ['R1', 'R2', 'R3']).map((r) => r.id), [
      'R1',
      'R2',
      'R3',
      'X',
      'Y',
    ]);
    // Sin catálogo todavía, el orden en que vinieron.
    expect(ordenarComoFlota(rutas, const []).map((r) => r.id), [
      'R3',
      'X',
      'R1',
      'Y',
      'R2',
    ]);
  });
}
