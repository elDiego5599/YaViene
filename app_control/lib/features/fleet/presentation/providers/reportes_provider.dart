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

/// Las fechas del periodo en Bogotá, de la primera a la última que toca:
/// «27 sep a 27 oct», «20 a 27 oct» o «27 oct». El año sale solo cuando no
/// es el de ahora.
String rangoFechasLabel(PeriodoReporte periodo, DateTime ahora) {
  final (desde, hasta) = rangoPeriodo(periodo, ahora);
  final ini = desde.subtract(_bogota);
  // El fin es exclusivo: la medianoche que cierra un día no es del otro.
  var fin = hasta.subtract(_bogota).subtract(const Duration(microseconds: 1));
  if (fin.isBefore(ini)) fin = ini;
  final anio = ahora.toUtc().subtract(_bogota).year;
  String mes(DateTime d) => _meses[d.month - 1].substring(0, 3);
  String fecha(DateTime d) =>
      '${d.day} ${mes(d)}${d.year == anio ? '' : ' ${d.year}'}';
  if (ini.year == fin.year && ini.month == fin.month) {
    if (ini.day == fin.day) return fecha(fin);
    return '${ini.day} a ${fecha(fin)}';
  }
  return '${fecha(ini)} a ${fecha(fin)}';
}

/// «los 30 días, 27 sep a 27 oct», «hoy, 27 oct» o «12 oct» (un día).
String _periodoConFechas(PeriodoReporte periodo, DateTime ahora) {
  final rango = rangoFechasLabel(periodo, ahora);
  if (periodo.dia != null) return rango;
  return switch (periodo.name) {
    'hoy' => 'hoy, $rango',
    'semana' => 'los 7 días, $rango',
    _ => 'los 30 días, $rango',
  };
}

/// Lo que suma el mapa de calor: todas las búsquedas del periodo.
String totalPeriodoLabel(PeriodoReporte periodo, DateTime ahora) {
  final cuando = _periodoConFechas(periodo, ahora);
  return periodo.dia != null ? 'Total del $cuando' : 'Total de $cuando';
}

/// El pie del mapa con una hora elegida: lo que suma esa hora, no el día.
String totalHoraLabel(
  PeriodoReporte periodo,
  DateTime ahora, {
  required int hora,
  required int busquedas,
}) {
  final cuantas = busquedas == 1 ? '1 búsqueda' : '$busquedas búsquedas';
  final cuando = _periodoConFechas(periodo, ahora);
  final enPeriodo = periodo.dia != null
      ? ' del $cuando'
      : periodo.name == 'hoy'
      ? ', $cuando'
      : ' en $cuando';
  return '$cuantas de ${horaPicoLabel(hora)}$enPeriodo';
}

/// Sin zonas que mostrar: el mapa solo pinta celdas con 5 o más (D17), y
/// con pocas búsquedas el pie dice que sí las hubo.
String sinZonasLabel(int busquedas) {
  if (busquedas == 0) return 'Sin zonas con 5 búsquedas o más';
  final cuantas = busquedas == 1 ? '1 búsqueda' : '$busquedas búsquedas';
  return 'Hay $cuantas, pero ninguna zona llega a 5';
}

/// Lo que promedia la ocupación: los buses de la ruta, día por día.
String promedioPeriodoLabel(
  PeriodoReporte periodo,
  DateTime ahora, {
  required int buses,
}) {
  if (buses == 0) return 'Esta ruta aún no tiene buses';
  final quien = buses == 1 ? 'De 1 bus' : 'Promedio de $buses buses';
  final cuando = _periodoConFechas(periodo, ahora);
  if (periodo.name == 'hoy') return '$quien $cuando';
  return periodo.dia != null ? '$quien el $cuando' : '$quien en $cuando';
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

/// Las píldoras de Reportes van en el orden de las de Flota («igual que la
/// flota», dueño, 2026-10-27); las rutas que Flota no tiene, al final, en el
/// orden en que llegan.
List<RutaBusquedas> ordenarComoFlota(
  List<RutaBusquedas> rutas,
  List<String> catalogo,
) {
  final porId = {for (final r in rutas) r.id: r};
  final enFlota = catalogo.toSet();
  return [
    for (final id in catalogo) ?porId[id],
    ...rutas.where((r) => !enFlota.contains(r.id)),
  ];
}

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
