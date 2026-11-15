import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/viaje_panel.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/viajes_provider.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

Map<String, Object?> _par(
  double olat,
  double olng,
  double dlat,
  double dlng,
  int total,
) => {
  'origen': {'lat': olat, 'lng': olng},
  'destino': {'lat': dlat, 'lng': dlng},
  'total': total,
};

class _Api extends FleetApi {
  _Api() : super(baseUrl: 'https://panel.test');
  int pedidos = 0;
  int? franja;
  List<int>? dias;
  DateTime? desde;

  @override
  Future<ReporteViajes> fetchViajes(
    String? token, {
    required DateTime desde,
    required DateTime hasta,
    int? franja,
    List<int> dias = const [],
  }) async {
    pedidos++;
    this.franja = franja;
    this.dias = dias;
    this.desde = desde;
    return ReporteViajes.fromJson({
      'pares': [_par(10.989, -74.791, 10.962, -74.802, 5)],
    });
  }
}

void main() {
  group('ReporteViajes', () {
    test('lee los pares como los manda el backend', () {
      final reporte = ReporteViajes.fromJson({
        'pares': [_par(10.989, -74.791, 10.962, -74.802, 5)],
      });
      final par = reporte.pares.single;
      expect(par.origen, (lat: 10.989, lng: -74.791));
      expect(par.destino, (lat: 10.962, lng: -74.802));
      expect(par.total, 5);
      expect(par.dentroDeLaZona, isFalse);
    });

    test('sin pares es el vacío', () {
      expect(ReporteViajes.fromJson({'pares': <Object>[]}).pares, isEmpty);
      expect(ReporteViajes.vacio.pares, isEmpty);
    });

    test(
      'un par con el mismo origen y destino se marca como dentro de la zona',
      () {
        final par = ParViaje.fromJson(
          _par(10.989, -74.791, 10.989, -74.791, 6),
        );
        expect(par.dentroDeLaZona, isTrue);
      },
    );

    test('las zonas se rotulan A, B, C por lo que mueven, de más a menos', () {
      final reporte = ReporteViajes.fromJson({
        'pares': [
          _par(10.989, -74.791, 10.962, -74.802, 9),
          _par(10.962, -74.802, 10.940, -74.780, 5),
          _par(10.989, -74.791, 10.940, -74.780, 5),
        ],
      });
      final zonas = reporte.zonas;
      // La primera zona toca 9 + 5 = 14 viajes, la segunda 14 también (9 + 5),
      // la tercera 10: el empate lo rompe el orden en que llegan.
      expect([for (final z in zonas) z.etiqueta], ['A', 'B', 'C']);
      expect(zonas.first.lat, 10.989);
      expect(zonas.first.salen, 14);
      expect(zonas.first.llegan, 0);
      expect(zonas[1].salen, 5);
      expect(zonas[1].llegan, 9);
      expect(zonas.last.llegan, 10);
    });

    test('pasada la Z los rótulos siguen con AA, AB', () {
      expect(etiquetaZona(0), 'A');
      expect(etiquetaZona(25), 'Z');
      expect(etiquetaZona(26), 'AA');
      expect(etiquetaZona(27), 'AB');
      expect(etiquetaZona(51), 'AZ');
      expect(etiquetaZona(52), 'BA');
    });

    test('de cada par se sabe el rótulo de su origen y de su destino', () {
      final reporte = ReporteViajes.fromJson({
        'pares': [_par(10.989, -74.791, 10.962, -74.802, 9)],
      });
      final (origen, destino) = reporte.etiquetasDe(reporte.pares.single);
      expect(origen, 'A');
      expect(destino, 'B');
    });

    test('el total suma todos los viajes', () {
      final reporte = ReporteViajes.fromJson({
        'pares': [
          _par(10.989, -74.791, 10.962, -74.802, 9),
          _par(10.962, -74.802, 10.940, -74.780, 5),
        ],
      });
      expect(reporte.total, 14);
    });
  });

  group('franjaLabel', () {
    test('cada franja dice sus tres horas', () {
      expect(franjaLabel(0), '12 a. m. a 3 a. m.');
      expect(franjaLabel(2), '6 a. m. a 9 a. m.');
      expect(franjaLabel(3), '9 a. m. a 12 p. m.');
      expect(franjaLabel(4), '12 p. m. a 3 p. m.');
      expect(franjaLabel(7), '9 p. m. a 12 a. m.');
    });
  });

  group('viajesProvider', () {
    late _Api api;
    late ProviderContainer container;

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

    test('pasa la franja, los días y el rango del periodo', () async {
      final lunes = PeriodoReporte.entre(
        DateTime(2026, 9, 2),
        DateTime(2026, 11, 2),
        dias: {3, 1},
      );
      final reporte = await container.read(
        viajesProvider((periodo: lunes, franja: 2)).future,
      );
      expect(reporte.pares.single.total, 5);
      expect(api.franja, 2);
      expect(api.dias, [1, 3]);

      await container.read(
        viajesProvider((periodo: PeriodoReporte.semana, franja: null)).future,
      );
      expect(api.franja, isNull);
      expect(api.dias, isEmpty);
    });

    test(
      'con un día elegido que no cae en el rango no gasta una lectura',
      () async {
        final fuera = PeriodoReporte.entre(
          DateTime(2026, 10, 13),
          DateTime(2026, 10, 15),
          dias: {DateTime.sunday},
        );
        expect(fuera.cuentaAlgunDia, isFalse);
        final reporte = await container.read(
          viajesProvider((periodo: fuera, franja: null)).future,
        );
        expect(reporte.pares, isEmpty);
        expect(api.pedidos, 0);
      },
    );
  });
}
