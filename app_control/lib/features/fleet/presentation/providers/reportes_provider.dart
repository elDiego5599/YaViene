import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import 'fleet_providers.dart' show fleetApiProvider;

/// Periodo del reporte: una ventana móvil (hoy, 7 o 30 días), un día del
/// calendario o un rango de días, que puede contar solo unos días de la
/// semana («todos los lunes entre hoy y hace 2 meses»). Es un valor: dos
/// periodos de los mismos días son iguales, para que los providers family
/// no repitan la consulta.
class PeriodoReporte {
  const PeriodoReporte._(this.name, [this.dia, this.fin, this.dias = const []]);

  /// Un día del calendario de Bogotá; la hora de [fecha] no cuenta.
  factory PeriodoReporte.delDia(DateTime fecha) =>
      PeriodoReporte._('dia', _soloDia(fecha));

  /// Del primer día al último, ambos enteros, en cualquier orden. Un rango
  /// de un solo día es ese día. [dias] deja solo esos días de la semana, del
  /// 1 (lunes) al 7 (domingo), como `DateTime.weekday`; los siete son
  /// ninguno.
  factory PeriodoReporte.entre(
    DateTime a,
    DateTime b, {
    Iterable<int> dias = const [],
  }) {
    final semana = dias.toSet().toList()..sort();
    if (semana.any((d) => d < DateTime.monday || d > DateTime.sunday)) {
      throw ArgumentError.value(dias, 'dias', 'van del 1 (lunes) al 7');
    }
    final (x, y) = (_soloDia(a), _soloDia(b));
    if (x == y) return PeriodoReporte.delDia(x);
    final elegidos = semana.length == 7
        ? const <int>[]
        : List<int>.unmodifiable(semana);
    return x.isBefore(y)
        ? PeriodoReporte._('rango', x, y, elegidos)
        : PeriodoReporte._('rango', y, x, elegidos);
  }

  static DateTime _soloDia(DateTime f) => DateTime.utc(f.year, f.month, f.day);

  static const hoy = PeriodoReporte._('hoy');
  static const semana = PeriodoReporte._('semana');
  static const mes = PeriodoReporte._('mes');
  static const values = [hoy, semana, mes];

  final String name;

  /// El primer día del calendario (el único, en un día suelto).
  final DateTime? dia;

  /// El último día de un rango; nulo en lo demás.
  final DateTime? fin;

  /// Los días de la semana que cuentan, de menor a mayor; vacía, todos.
  final List<int> dias;

  bool get esRango => fin != null;

  /// Si alguno de los días elegidos cae en el rango: del martes al
  /// miércoles no hay domingos, y pedirlos no tiene que viajar al servidor.
  bool get cuentaAlgunDia {
    final dia = this.dia, fin = this.fin;
    if (dias.isEmpty || dia == null || fin == null) return true;
    final largo = fin.difference(dia).inDays + 1;
    if (largo >= 7) return true;
    return [
      for (var i = 0; i < largo; i++) dia.add(Duration(days: i)).weekday,
    ].any(dias.contains);
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodoReporte &&
      other.name == name &&
      other.dia == dia &&
      other.fin == fin &&
      listEquals(other.dias, dias);

  @override
  int get hashCode => Object.hash(name, dia, fin, Object.hashAll(dias));
}

const _diasSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// «lun», «mié», «sáb»: los tres primeros, con su tilde.
String diaCorto(int dia) => _diasSemana[dia - 1].substring(0, 3);

/// «a», «a y b», «a, b y c».
String _enLista(List<String> partes) => partes.length == 1
    ? partes.single
    : '${partes.sublist(0, partes.length - 1).join(', ')} y ${partes.last}';

/// «los lunes», «los sábados y domingos»: sábado y domingo llevan su s.
String _losDias(List<int> dias) =>
    'los ${_enLista([for (final d in dias) d >= DateTime.saturday ? '${_diasSemana[d - 1]}s' : _diasSemana[d - 1]])}';

/// Bogotá va en UTC-5 todo el año: su medianoche es las 5:00 UTC.
const _bogota = Duration(hours: 5);

(DateTime, DateTime) rangoPeriodo(PeriodoReporte periodo, DateTime ahora) {
  final hasta = ahora.toUtc();
  final dia = periodo.dia;
  if (dia != null) {
    final desde = dia.add(_bogota);
    final fin = (periodo.fin ?? dia).add(_bogota).add(const Duration(days: 1));
    // El día de hoy corta en este momento, no en la medianoche que viene.
    return (desde, fin.isAfter(hasta) ? hasta : fin);
  }
  // Días de Bogotá enteros, hoy incluido: el servidor redondea el rango a
  // medianoches (AUD29-01) y 7 × 24 h le tocarían un octavo día.
  final local = hasta.subtract(_bogota);
  final hoy = DateTime.utc(local.year, local.month, local.day).add(_bogota);
  final dias = switch (periodo.name) {
    'hoy' => 1,
    'semana' => 7,
    _ => 30,
  };
  return (hoy.subtract(Duration(days: dias - 1)), hasta);
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
  String mes(DateTime d) => _meses[d.month - 1].substring(0, 3);
  final dia = periodo.dia;
  final fin = periodo.fin;
  if (fin != null && dia != null) {
    final fechas = dia.month == fin.month
        ? '${dia.day} a ${fin.day} ${mes(fin)}'
        : '${dia.day} ${mes(dia)} a ${fin.day} ${mes(fin)}';
    final dias = periodo.dias;
    if (dias.isEmpty) return fechas;
    // Un día va entero; varios, cortos, para que el segmento no crezca.
    if (dias.length == 1) return '$fechas, ${_diasSemana[dias.single - 1]}';
    return '$fechas, ${_enLista([for (final d in dias) diaCorto(d)])}';
  }
  if (dia != null) return '${dia.day} ${mes(dia)}';
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

/// «los 30 días, 27 sep a 27 oct», «hoy, 27 oct», «12 oct» (un día),
/// «20 a 25 oct» (un rango) o «los lunes, 2 sep a 2 nov» (unos días del
/// rango).
String _periodoConFechas(PeriodoReporte periodo, DateTime ahora) {
  final rango = rangoFechasLabel(periodo, ahora);
  if (periodo.dias.isNotEmpty) return '${_losDias(periodo.dias)}, $rango';
  if (periodo.dia != null) return rango;
  return switch (periodo.name) {
    'hoy' => 'hoy, $rango',
    'semana' => 'los 7 días, $rango',
    _ => 'los 30 días, $rango',
  };
}

/// «del 12 oct», pero «de los lunes, …».
bool _del(PeriodoReporte periodo) =>
    periodo.dia != null && periodo.dias.isEmpty;

/// Lo que suma el mapa de calor: todas las búsquedas del periodo.
String totalPeriodoLabel(PeriodoReporte periodo, DateTime ahora) {
  final cuando = _periodoConFechas(periodo, ahora);
  return _del(periodo) ? 'Total del $cuando' : 'Total de $cuando';
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
  final enPeriodo = _del(periodo)
      ? ' del $cuando'
      : periodo.dias.isNotEmpty
      ? ' de $cuando'
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
  if (periodo.dias.isNotEmpty) return '$quien de $cuando';
  if (periodo.esRango) return '$quien del $cuando';
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
      // Ningún día elegido cae en el rango: vacío sin gastar una lectura.
      if (!args.periodo.cuentaAlgunDia) return const [];
      // Solo el token: otro cambio de la sesión no vuelve a pedir el reporte.
      final token = ref.watch(authProvider.select((s) => s.session?.token));
      final (desde, hasta) = rangoPeriodo(args.periodo, clock.now());
      final data = await ref
          .watch(fleetApiProvider)
          .fetchSearchReports(
            token,
            desde: desde,
            hasta: hasta,
            hora: args.hora,
            dias: args.periodo.dias,
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
      // Ningún día elegido cae en el rango: vacío sin gastar una lectura.
      if (!args.periodo.cuentaAlgunDia) return const [];
      // Solo el token: otro cambio de la sesión no vuelve a pedir el reporte.
      final token = ref.watch(authProvider.select((s) => s.session?.token));
      final (desde, hasta) = rangoPeriodo(args.periodo, clock.now());
      final data = await ref
          .watch(fleetApiProvider)
          .fetchSearchHeatmap(
            token,
            routeId: args.routeId,
            desde: desde,
            hasta: hasta,
            hora: args.hora,
            dias: args.periodo.dias,
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

/// Cuándo pasó algo, en Bogotá: «10 nov, 3 p. m.», o solo el día si no se
/// sabe la hora.
String cuandoLabel(DateTime instante, {required bool conHora}) {
  final bogota = instante.toUtc().subtract(const Duration(hours: 5));
  final dia = '${bogota.day} ${_meses[bogota.month - 1].substring(0, 3)}';
  return conHora ? '$dia, ${horaOpcionLabel(bogota.hour)}' : dia;
}

String horaOpcionLabel(int hora) {
  final sufijo = hora < 12 ? 'a. m.' : 'p. m.';
  final hora12 = hora % 12 == 0 ? 12 : hora % 12;
  return '$hora12 $sufijo';
}
