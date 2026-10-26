import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fleet_providers.dart';
import 'reportes_provider.dart';

/// Primera hora de servicio: las barras van de 5 a. m. a 11 p. m.
const primeraHoraServicio = 5;
const _ultimaHora = 23;

/// Un día de ejemplo, en %: los picos de la mañana y la tarde llenos, el
/// mediodía y la noche vacíos. Ningún bus tiene aún cámara de aforo
/// (`YaVieneBackend/prototipo-aforo`); cada bus y cada día se mueven
/// alrededor de esta forma para que la empresa vea lo que verá.
const _forma = [
  38, 82, 88, 61, 42, 24, 18, 47, 44, 19, //
  26, 53, 84, 90, 63, 41, 30, 20, 12,
];

/// Bogotá va en UTC-5 todo el año.
const _bogota = Duration(hours: 5);

/// FNV-1a de 32 bits: `String.hashCode` no promete ser el mismo entre
/// ejecuciones, y el ejemplo tiene que serlo.
int _hash(String texto) {
  var h = 0x811c9dc5;
  for (final c in texto.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// De -1 a 1, fijo para cada texto.
double _ruido(String texto) => _hash(texto) / 0x7fffffff - 1;

/// Ocupación de ejemplo de la ruta, en %, una por hora de servicio: el
/// promedio de cada bus de la ruta en cada día del periodo. Una hora que aún
/// no llega (o una ruta sin buses) va en null: no se inventa lo que no pasó.
List<int?> ocupacionEjemplo({
  required String routeId,
  required List<String> buses,
  required PeriodoReporte periodo,
  required DateTime ahora,
}) {
  final (desde, hasta) = rangoPeriodo(periodo, ahora);
  // Hay rutas que van más llenas que otras: 75 % a 110 % de la forma.
  final carga = 0.925 + 0.175 * _ruido('ruta $routeId');
  final local = desde.subtract(_bogota);
  final sumas = List.filled(_forma.length, 0);
  final cuentas = List.filled(_forma.length, 0);
  for (
    var dia = DateTime.utc(local.year, local.month, local.day);
    dia.add(_bogota).isBefore(hasta);
    dia = dia.add(const Duration(days: 1))
  ) {
    final fecha = '${dia.year}-${dia.month}-${dia.day}';
    // Sábado y domingo se mueve menos gente.
    final finde = dia.weekday >= DateTime.saturday ? 0.7 : 1.0;
    final delDia = finde * (1 + 0.08 * _ruido('$routeId $fecha'));
    for (var h = primeraHoraServicio; h <= _ultimaHora; h++) {
      final inicio = dia.add(_bogota).add(Duration(hours: h));
      final fin = inicio.add(const Duration(hours: 1));
      if (!inicio.isBefore(hasta) || !fin.isAfter(desde)) continue;
      final i = h - primeraHoraServicio;
      for (final bus in buses) {
        final pct =
            _forma[i] * carga * delDia + 12 * _ruido('$routeId $bus $fecha $h');
        sumas[i] += pct.round().clamp(0, 100);
        cuentas[i]++;
      }
    }
  }
  return [
    for (var i = 0; i < _forma.length; i++)
      cuentas[i] == 0 ? null : (sumas[i] / cuentas[i]).round(),
  ];
}

/// La ocupación de la ruta en el periodo, con los buses que hoy tiene la
/// flota en esa ruta.
final ocupacionProvider =
    Provider.family<List<int?>, ({String routeId, PeriodoReporte periodo})>((
      ref,
      args,
    ) {
      final buses = ref.watch(
        fleetProvider.select(
          (s) => [
            for (final b in s.buses.values)
              if (b.routeId == args.routeId) b.busId,
          ]..sort(),
        ),
      );
      return ocupacionEjemplo(
        routeId: args.routeId,
        buses: buses,
        periodo: args.periodo,
        ahora: DateTime.now(),
      );
    });
