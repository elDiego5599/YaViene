import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import 'fleet_providers.dart' show fleetApiProvider;

/// Periodo del reporte: una ventana móvil (hoy, 7 o 30 días) o un día del
/// calendario. Es un valor: dos periodos del mismo día son iguales, para que
/// los providers family no repitan la consulta.
class PeriodoReporte {
  const PeriodoReporte._(this.name, [this.dia]);

  /// Un día del calendario de Bogotá; la hora de [fecha] no cuenta.
  factory PeriodoReporte.delDia(DateTime fecha) =>
      PeriodoReporte._('dia', DateTime.utc(fecha.year, fecha.month, fecha.day));

  static const hoy = PeriodoReporte._('hoy');
  static const semana = PeriodoReporte._('semana');
  static const mes = PeriodoReporte._('mes');
  static const values = [hoy, semana, mes];

  final String name;
  final DateTime? dia;

  @override
  bool operator ==(Object other) =>
      other is PeriodoReporte && other.name == name && other.dia == dia;

  @override
  int get hashCode => Object.hash(name, dia);
}

/// Bogotá va en UTC-5 todo el año: su medianoche es las 5:00 UTC.
const _bogota = Duration(hours: 5);

(DateTime, DateTime) rangoPeriodo(PeriodoReporte periodo, DateTime ahora) {
  final hasta = ahora.toUtc();
  final dia = periodo.dia;
  if (dia != null) {
    final desde = dia.add(_bogota);
    final fin = desde.add(const Duration(days: 1));
    // El día de hoy corta en este momento, no en la medianoche que viene.
    return (desde, fin.isAfter(hasta) ? hasta : fin);
  }
  final local = hasta.subtract(_bogota);
  final desde = switch (periodo.name) {
    'hoy' => DateTime.utc(local.year, local.month, local.day).add(_bogota),
    'semana' => hasta.subtract(const Duration(days: 7)),
    _ => hasta.subtract(const Duration(days: 30)),
  };
  return (desde, hasta);
}

const _meses = [
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

String periodoLabel(PeriodoReporte periodo) {
  final dia = periodo.dia;
  if (dia != null) return '${dia.day} ${_meses[dia.month - 1].substring(0, 3)}';
  return switch (periodo.name) {
    'hoy' => 'Hoy',
    'semana' => '7 días',
    _ => '30 días',
  };
}

class RutaBusquedas {
  const RutaBusquedas({
    required this.id,
    required this.nombre,
    required this.total,
    required this.porHora,
    required this.horaPico,
  });

  final String id;
  final String nombre;
  final int total;
  final int? horaPico;
  final List<int> porHora;

  factory RutaBusquedas.fromJson(Map<String, dynamic> json) => RutaBusquedas(
    id: json['routeId'] as String,
    nombre: json['name'] as String,
    total: (json['total'] as num).toInt(),
    porHora: (json['porHora'] as List)
        .map((value) => (value as num).toInt())
        .toList(),
    horaPico: (json['horaPico'] as num?)?.toInt(),
  );
}

class CeldaBusqueda {
  const CeldaBusqueda({
    required this.lat,
    required this.lng,
    required this.count,
  });

  final double lat;
  final double lng;
  final int count;

  factory CeldaBusqueda.fromJson(Map<String, dynamic> json) => CeldaBusqueda(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    count: (json['count'] as num).toInt(),
  );
}

final reportesRutasProvider =
    FutureProvider.family<
      List<RutaBusquedas>,
      ({PeriodoReporte periodo, int? hora})
    >((ref, args) async {
      final token = ref.watch(authProvider).session?.token;
      final (desde, hasta) = rangoPeriodo(args.periodo, DateTime.now());
      final data = await ref
          .watch(fleetApiProvider)
          .fetchSearchReports(
            token,
            desde: desde,
            hasta: hasta,
            hora: args.hora,
          );
      final rutas = (data['rutas'] as List)
          .map(
            (item) =>
                RutaBusquedas.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      return ordenarRutasBusquedas(rutas);
    });

/// Orden estable compartido por el provider y la pantalla del reporte.
List<RutaBusquedas> ordenarRutasBusquedas(Iterable<RutaBusquedas> rutas) =>
    rutas.toList()..sort((a, b) => b.total.compareTo(a.total));

final reportesCalorProvider =
    FutureProvider.family<
      List<CeldaBusqueda>,
      ({String routeId, PeriodoReporte periodo, int? hora})
    >((ref, args) async {
      final token = ref.watch(authProvider).session?.token;
      final (desde, hasta) = rangoPeriodo(args.periodo, DateTime.now());
      final data = await ref
          .watch(fleetApiProvider)
          .fetchSearchHeatmap(
            token,
            routeId: args.routeId,
            desde: desde,
            hasta: hasta,
            hora: args.hora,
          );
      return (data['celdas'] as List)
          .map(
            (item) =>
                CeldaBusqueda.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    });

/// Conversión única del índice 0-23 a la franja que usa el informe.
String horaPicoLabel(int hora) {
  final siguiente = (hora + 1) % 24;
  final suffix = hora < 12 ? 'a. m.' : 'p. m.';
  final nextSuffix = siguiente < 12 ? 'a. m.' : 'p. m.';
  final inicio = hora % 12 == 0 ? 12 : hora % 12;
  final fin = siguiente % 12 == 0 ? 12 : siguiente % 12;
  if (suffix == nextSuffix && hora % 12 != 0) {
    return '$inicio a $fin $suffix';
  }
  return '$inicio $suffix a $fin $nextSuffix';
}

String horaOpcionLabel(int hora) {
  final sufijo = hora < 12 ? 'a. m.' : 'p. m.';
  final hora12 = hora % 12 == 0 ? 12 : hora % 12;
  return '$hora12 $sufijo';
}
