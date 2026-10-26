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
    expect(periodoSubtitulo(PeriodoReporte.hoy), 'Hoy');
    expect(periodoSubtitulo(PeriodoReporte.semana), 'Últimos 7 días');
    expect(periodoSubtitulo(PeriodoReporte.mes), 'Últimos 30 días');
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
    expect(periodoSubtitulo(dia), '24 de octubre');
    expect(
      periodoSubtitulo(PeriodoReporte.delDia(DateTime(2026, 1, 3))),
      '3 de enero',
    );
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
}
