import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/queja_panel.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/quejas_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;
import 'package:ya_viene_core/ya_viene_core.dart' show MotivoQueja;

Map<String, Object?> _queja({
  String id = 'Q1',
  String motivo = 'iba_lleno',
  Object? celda,
  int? hora,
  int creado = 1767225600000,
}) => {
  'id': id,
  'motivo': motivo,
  'texto': 'Iba muy lleno',
  'routeId': 'R-101',
  'ruta': 'B18 Tcherassi',
  'busId': null,
  'celda': celda,
  'hora': hora,
  'creado': creado,
};

class _Api extends FleetApi {
  _Api() : super(baseUrl: 'https://panel.test');
  int pedidos = 0;
  String? ruta;
  MotivoQueja? motivo;
  List<int>? dias;
  DateTime? desde;

  @override
  Future<ReporteQuejas> fetchQuejas(
    String? token, {
    required DateTime desde,
    required DateTime hasta,
    String? routeId,
    MotivoQueja? motivo,
    List<int> dias = const [],
  }) async {
    pedidos++;
    ruta = routeId;
    this.motivo = motivo;
    this.dias = dias;
    this.desde = desde;
    return ReporteQuejas.fromJson({
      'quejas': [_queja()],
      'celdas': <Object>[],
    });
  }
}

void main() {
  group('QuejaPanel', () {
    test('sin hora del hecho cuenta desde que llegó', () {
      final queja = QuejaPanel.fromJson(_queja());
      expect(queja.hora, isNull);
      expect(queja.cuando, DateTime.utc(2026));
      expect(queja.busId, isNull);
      expect(queja.celda, isNull);
    });

    test('con hora del hecho cuenta desde ella', () {
      final queja = QuejaPanel.fromJson(_queja(hora: 1767225600000 - 3600000));
      expect(queja.cuando, DateTime.utc(2025, 12, 31, 23));
    });

    // Un motivo nuevo del backend no tumba la lista: sale como «Otro».
    test('un motivo que el panel no conoce no rompe la lectura', () {
      expect(QuejaPanel.fromJson(_queja(motivo: 'nuevo')).motivo, isNull);
    });

    test('la lista llega al tope del servidor con 500', () {
      ReporteQuejas con(int n) => ReporteQuejas.fromJson({
        'quejas': [for (var i = 0; i < n; i++) _queja(id: 'Q$i')],
        'celdas': <Object>[],
      });
      expect(con(499).alTope, isFalse);
      expect(con(500).alTope, isTrue);
    });
  });

  group('quejasProvider', () {
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

    test('pasa ruta, motivo, días y el rango del periodo', () async {
      final lunes = PeriodoReporte.entre(
        DateTime(2026, 9, 2),
        DateTime(2026, 11, 2),
        dias: {3, 1},
      );
      final reporte = await container.read(
        quejasProvider((
          routeId: 'R-101',
          periodo: lunes,
          motivo: MotivoQueja.malTrato,
        )).future,
      );
      expect(reporte.quejas.single.id, 'Q1');
      expect(api.ruta, 'R-101');
      expect(api.motivo, MotivoQueja.malTrato);
      expect(api.dias, [1, 3]);

      await container.read(
        quejasProvider((
          routeId: null,
          periodo: PeriodoReporte.semana,
          motivo: null,
        )).future,
      );
      expect(api.ruta, isNull);
      expect(api.motivo, isNull);
      expect(DateTime.now().toUtc().difference(api.desde!).inDays, 6);
    });

    test('sin ningún día elegido en el rango no se pide nada', () async {
      final domingos = PeriodoReporte.entre(
        DateTime(2026, 10, 13),
        DateTime(2026, 10, 15),
        dias: {DateTime.sunday},
      );
      final reporte = await container.read(
        quejasProvider((routeId: null, periodo: domingos, motivo: null)).future,
      );
      expect(reporte.quejas, isEmpty);
      expect(reporte.celdas, isEmpty);
      expect(api.pedidos, 0);
    });
  });
}
