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
  List<int>? diasRutas;
  List<int>? diasCalor;

  @override
  Future<Map<String, dynamic>> fetchSearchReports(
    String? token, {
    required DateTime desde,
    required DateTime hasta,
    int? hora,
    List<int> dias = const [],
  }) async {
    horaRutas = hora;
    diasRutas = dias;
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
    List<int> dias = const [],
  }) async {
    rutaCalor = routeId;
    diasCalor = dias;
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
  // El servidor cuenta días de Bogotá enteros (AUD29-01): «7 días» es hoy y
  // los 6 anteriores, desde su medianoche, no 7 × 24 h que tocan un octavo.
  test('rangoPeriodo usa días enteros de Bogotá', () {
    final ahora = DateTime.utc(2026, 10, 26, 3);
    expect(
      rangoPeriodo(PeriodoReporte.hoy, ahora).$1,
      DateTime.utc(2026, 10, 25, 5),
    );
    expect(rangoPeriodo(PeriodoReporte.hoy, ahora).$2, ahora);
    expect(
      rangoPeriodo(PeriodoReporte.semana, ahora).$1,
      DateTime.utc(2026, 10, 19, 5),
    );
    expect(
      rangoPeriodo(PeriodoReporte.mes, ahora).$1,
      DateTime.utc(2026, 9, 26, 5),
    );
    expect(rangoPeriodo(PeriodoReporte.mes, ahora).$2, ahora);
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

  test('un rango va de la medianoche del primero a la del último', () {
    final ahora = DateTime.utc(2026, 10, 27, 20);
    // El orden de los extremos no cuenta, ni su hora.
    final rango = PeriodoReporte.entre(
      DateTime(2026, 10, 25, 9),
      DateTime(2026, 10, 20),
    );
    expect(
      rango,
      PeriodoReporte.entre(DateTime(2026, 10, 20), DateTime(2026, 10, 25)),
    );
    expect(
      rango,
      isNot(
        PeriodoReporte.entre(DateTime(2026, 10, 20), DateTime(2026, 10, 24)),
      ),
    );
    expect(rangoPeriodo(rango, ahora), (
      DateTime.utc(2026, 10, 20, 5),
      DateTime.utc(2026, 10, 26, 5),
    ));
    // Hasta hoy corta en este momento.
    expect(
      rangoPeriodo(
        PeriodoReporte.entre(DateTime(2026, 10, 20), DateTime(2026, 10, 27)),
        ahora,
      ).$2,
      ahora,
    );
    // Un rango de un solo día es ese día.
    final unDia = PeriodoReporte.delDia(DateTime(2026, 10, 20));
    expect(
      PeriodoReporte.entre(DateTime(2026, 10, 20), DateTime(2026, 10, 20, 8)),
      unDia,
    );
    expect(unDia.esRango, isFalse);
    expect(rango.esRango, isTrue);
    expect(rango.fin, DateTime.utc(2026, 10, 25));
    expect(periodoLabel(rango), '20 a 25 oct');
    expect(
      periodoLabel(
        PeriodoReporte.entre(DateTime(2026, 9, 28), DateTime(2026, 10, 3)),
      ),
      '28 sep a 3 oct',
    );
  });

  test('los rótulos del rango cuentan sus días', () {
    final ahora = DateTime.utc(2026, 10, 27, 20);
    final rango = PeriodoReporte.entre(
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 25),
    );
    expect(rangoFechasLabel(rango, ahora), '20 a 25 oct');
    expect(totalPeriodoLabel(rango, ahora), 'Total del 20 a 25 oct');
    expect(
      totalHoraLabel(rango, ahora, hora: 7, busquedas: 4),
      '4 búsquedas de 7 a 8 a. m. del 20 a 25 oct',
    );
    expect(
      promedioPeriodoLabel(rango, ahora, buses: 2),
      'Promedio de 2 buses del 20 a 25 oct',
    );
  });

  group('días de la semana dentro del rango', () {
    final ahora = DateTime.utc(2026, 11, 2, 20);
    final rango = PeriodoReporte.entre(
      DateTime(2026, 9, 2),
      DateTime(2026, 11, 2),
      dias: {3, 1},
    );

    test('es un valor: los mismos días en otro orden son el mismo periodo', () {
      expect(rango.dias, [1, 3]);
      expect(
        rango,
        PeriodoReporte.entre(
          DateTime(2026, 11, 2),
          DateTime(2026, 9, 2),
          dias: [1, 3, 3],
        ),
      );
      expect(
        rango.hashCode,
        PeriodoReporte.entre(
          DateTime(2026, 9, 2),
          DateTime(2026, 11, 2),
          dias: {1, 3},
        ).hashCode,
      );
      expect(
        rango,
        isNot(
          PeriodoReporte.entre(DateTime(2026, 9, 2), DateTime(2026, 11, 2)),
        ),
      );
    });

    test('los siete días son lo mismo que ninguno', () {
      expect(
        PeriodoReporte.entre(
          DateTime(2026, 9, 2),
          DateTime(2026, 11, 2),
          dias: {1, 2, 3, 4, 5, 6, 7},
        ),
        PeriodoReporte.entre(DateTime(2026, 9, 2), DateTime(2026, 11, 2)),
      );
    });

    test('un día que no es de la semana no entra', () {
      expect(
        () => PeriodoReporte.entre(
          DateTime(2026, 9, 2),
          DateTime(2026, 11, 2),
          dias: {0},
        ),
        throwsArgumentError,
      );
    });

    test('dice si alguno de los días cae en el rango', () {
      // Del martes 20 al miércoles 21 de octubre.
      final corto = DateTime(2026, 10, 20);
      final fin = DateTime(2026, 10, 21);
      expect(PeriodoReporte.entre(corto, fin, dias: {7}).cuentaAlgunDia, false);
      expect(
        PeriodoReporte.entre(corto, fin, dias: {7, 3}).cuentaAlgunDia,
        true,
      );
      expect(PeriodoReporte.entre(corto, fin).cuentaAlgunDia, true);
      expect(PeriodoReporte.mes.cuentaAlgunDia, true);
    });

    test('los rótulos dicen qué días cuentan', () {
      final lunes = PeriodoReporte.entre(
        DateTime(2026, 9, 2),
        DateTime(2026, 11, 2),
        dias: {1},
      );
      final finde = PeriodoReporte.entre(
        DateTime(2026, 9, 2),
        DateTime(2026, 11, 2),
        dias: {6, 7},
      );
      expect(periodoLabel(lunes), '2 sep a 2 nov, lunes');
      expect(periodoLabel(rango), '2 sep a 2 nov, lun y mié');
      expect(
        periodoLabel(
          PeriodoReporte.entre(
            DateTime(2026, 9, 2),
            DateTime(2026, 11, 2),
            dias: {5, 1, 3},
          ),
        ),
        '2 sep a 2 nov, lun, mié y vie',
      );
      expect(
        totalPeriodoLabel(lunes, ahora),
        'Total de los lunes, 2 sep a 2 nov',
      );
      expect(
        totalPeriodoLabel(finde, ahora),
        'Total de los sábados y domingos, 2 sep a 2 nov',
      );
      expect(
        totalHoraLabel(rango, ahora, hora: 7, busquedas: 4),
        '4 búsquedas de 7 a 8 a. m. de los lunes y miércoles, 2 sep a 2 nov',
      );
      expect(
        promedioPeriodoLabel(lunes, ahora, buses: 2),
        'Promedio de 2 buses de los lunes, 2 sep a 2 nov',
      );
    });
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
      // Hoy y los 29 días anteriores, desde su medianoche.
      expect(DateTime.now().toUtc().difference(api.desdeRutas!).inDays, 29);
      await container.read(
        reportesRutasProvider((
          periodo: PeriodoReporte.semana,
          hora: null,
        )).future,
      );
      expect(DateTime.now().toUtc().difference(api.desdeRutas!).inDays, 6);

      final cells = await container.read(
        reportesCalorProvider((
          routeId: 'R2',
          periodo: PeriodoReporte.semana,
          hora: 8,
        )).future,
      );
      expect(api.rutaCalor, 'R2');
      expect(DateTime.now().toUtc().difference(api.desdeCalor!).inDays, 6);
      expect(api.horaCalor, 8);
      expect(cells.single.count, 5);
    },
  );

  test('los providers piden solo los días elegidos', () async {
    final lunes = PeriodoReporte.entre(
      DateTime(2026, 9, 2),
      DateTime(2026, 11, 2),
      dias: {3, 1},
    );
    await container.read(
      reportesRutasProvider((periodo: lunes, hora: null)).future,
    );
    expect(api.diasRutas, [1, 3]);
    await container.read(
      reportesCalorProvider((routeId: 'R1', periodo: lunes, hora: 8)).future,
    );
    expect(api.diasCalor, [1, 3]);
    await container.read(
      reportesRutasProvider((periodo: PeriodoReporte.mes, hora: null)).future,
    );
    expect(api.diasRutas, isEmpty);
  });

  // Ningún domingo cae del martes al jueves: la lista sale vacía sin
  // gastar una lectura del servidor (le caben 120 por minuto).
  test('sin ningún día elegido en el rango no se pide nada', () async {
    final domingos = PeriodoReporte.entre(
      DateTime(2026, 10, 13),
      DateTime(2026, 10, 15),
      dias: {DateTime.sunday},
    );
    expect(
      await container.read(
        reportesRutasProvider((periodo: domingos, hora: null)).future,
      ),
      isEmpty,
    );
    expect(
      await container.read(
        reportesCalorProvider((
          routeId: 'R1',
          periodo: domingos,
          hora: 8,
        )).future,
      ),
      isEmpty,
    );
    expect(api.diasRutas, isNull);
    expect(api.diasCalor, isNull);
  });

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
      expect(rangoFechasLabel(PeriodoReporte.mes, ahora), '28 sep a 27 oct');
      expect(rangoFechasLabel(PeriodoReporte.semana, ahora), '21 a 27 oct');
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
        '12 dic 2026 a 10 ene',
      );
      expect(
        rangoFechasLabel(PeriodoReporte.delDia(DateTime(2026, 12, 31)), enero),
        '31 dic 2026',
      );
    });

    test('el mapa dice que suma las búsquedas del periodo', () {
      expect(
        totalPeriodoLabel(PeriodoReporte.mes, ahora),
        'Total de los 30 días, 28 sep a 27 oct',
      );
      expect(
        totalPeriodoLabel(PeriodoReporte.semana, ahora),
        'Total de los 7 días, 21 a 27 oct',
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

    test('con una hora elegida el pie cuenta solo esa hora', () {
      expect(
        totalHoraLabel(PeriodoReporte.hoy, ahora, hora: 12, busquedas: 3),
        '3 búsquedas de 12 p. m. a 1 p. m., hoy, 27 oct',
      );
      expect(
        totalHoraLabel(PeriodoReporte.mes, ahora, hora: 7, busquedas: 1),
        '1 búsqueda de 7 a 8 a. m. en los 30 días, 28 sep a 27 oct',
      );
      expect(
        totalHoraLabel(
          PeriodoReporte.delDia(DateTime(2026, 10, 12)),
          ahora,
          hora: 7,
          busquedas: 0,
        ),
        '0 búsquedas de 7 a 8 a. m. del 12 oct',
      );
    });

    test('sin zonas dice si hubo búsquedas que no llegan a 5', () {
      expect(sinZonasLabel(0), 'Sin zonas con 5 búsquedas o más');
      expect(sinZonasLabel(1), 'Hay 1 búsqueda, pero ninguna zona llega a 5');
      expect(sinZonasLabel(4), 'Hay 4 búsquedas, pero ninguna zona llega a 5');
    });

    test('la ocupación dice que promedia sus buses en el periodo', () {
      expect(
        promedioPeriodoLabel(PeriodoReporte.mes, ahora, buses: 3),
        'Promedio de 3 buses en los 30 días, 28 sep a 27 oct',
      );
      expect(
        promedioPeriodoLabel(PeriodoReporte.semana, ahora, buses: 1),
        'De 1 bus en los 7 días, 21 a 27 oct',
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
