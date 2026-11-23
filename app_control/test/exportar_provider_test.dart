import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/exportar_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

class _Api extends FleetApi {
  _Api() : super(baseUrl: 'https://panel.test');
  String? token;
  String? routeId;
  DateTime? desde;
  DateTime? hasta;
  List<int>? dias;
  Object? falla;

  @override
  Future<({String texto, String nombre})> fetchIndicadoresCsv(
    String? token, {
    required String routeId,
    required DateTime desde,
    required DateTime hasta,
    List<int> dias = const [],
  }) async {
    this.token = token;
    this.routeId = routeId;
    this.desde = desde;
    this.hasta = hasta;
    this.dias = dias;
    if (falla case final falla?) throw falla;
    return (texto: 'ruta,hora\r\nR1,6\r\n', nombre: 'indicadores-R1.csv');
  }
}

void main() {
  late _Api api;
  late List<(String, String)> guardados;
  late String? respuesta;
  late ProviderContainer container;

  setUp(() {
    api = _Api();
    guardados = [];
    respuesta = 'indicadores-R1.csv';
    container = ProviderContainer(
      overrides: [
        backendUrlProvider.overrideWith(
          () => BackendUrl.fija('https://panel.test'),
        ),
        fleetApiProvider.overrideWithValue(api),
        guardarArchivoProvider.overrideWithValue((nombre, texto) async {
          guardados.add((nombre, texto));
          return respuesta;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(authProvider.notifier).state = const AuthState(
      status: AuthStatus.authenticated,
      session: AuthSession(
        token: 'session-token',
        companyId: 'EMP-1',
        companyName: 'Empresa',
      ),
    );
  });

  Future<String?> exportar(PeriodoReporte periodo) => withClock(
    Clock.fixed(DateTime.utc(2026, 10, 27, 20)),
    () => container.read(exportarIndicadoresProvider)('R1', periodo),
  );

  test(
    'pide el CSV del periodo y lo guarda con el nombre del servidor',
    () async {
      final periodo = PeriodoReporte.entre(
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 25),
        dias: const [DateTime.monday, DateTime.friday],
      );

      expect(await exportar(periodo), 'indicadores-R1.csv');

      expect(api.token, 'session-token');
      expect(api.routeId, 'R1');
      expect(api.desde, DateTime.utc(2026, 10, 20, 5));
      expect(api.hasta, DateTime.utc(2026, 10, 26, 5));
      expect(api.dias, [DateTime.monday, DateTime.friday]);
      expect(guardados, [('indicadores-R1.csv', 'ruta,hora\r\nR1,6\r\n')]);
    },
  );

  test('cerrar el diálogo de guardar devuelve null', () async {
    respuesta = null;
    expect(await exportar(PeriodoReporte.semana), isNull);
    expect(guardados, hasLength(1));
  });

  test('si el servidor falla no se abre el diálogo', () async {
    api.falla = const SessionExpiredException();
    await expectLater(
      exportar(PeriodoReporte.hoy),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(guardados, isEmpty);
  });
}
