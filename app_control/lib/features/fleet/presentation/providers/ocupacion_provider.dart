import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fleet_providers.dart';
import 'reportes_provider.dart';

/// Primera hora de servicio: las barras van de 5 a. m. a 11 p. m.
const primeraHoraServicio = 5;
const _ultimaHora = 23;

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

/// De 0 a 1, fijo para cada texto.
double _azar(String texto) => (_ruido(texto) + 1) / 2;

/// El día de ejemplo de la ruta, en %, una por hora de servicio. Ningún bus
/// tiene aún cámara de aforo (`YaVieneBackend/prototipo-aforo`). Todas se
/// llenan en la mañana y en la tarde, pero cada una a su hora (6 a 8 y 4 a
/// 6), con su ancho y su alto, un mediodía propio y un valle que no es
/// plano; así dos rutas no son la misma curva escalada.
List<double> _forma(String routeId) {
  double campana(double h, double centro, double ancho) =>
      math.exp(-math.pow(h - centro, 2) / (2 * ancho * ancho));
  final manana = 6.5 + 1.5 * _azar('$routeId mañana');
  final tarde = 16.5 + 2 * _azar('$routeId tarde');
  final altoManana = 62 + 28 * _azar('$routeId alto mañana');
  final altoTarde = 62 + 28 * _azar('$routeId alto tarde');
  final anchoManana = 0.8 + 0.6 * _azar('$routeId ancho mañana');
  final anchoTarde = 0.9 + 0.7 * _azar('$routeId ancho tarde');
  final mediodia = 12 + _azar('$routeId mediodía');
  final altoMediodia = 10 + 25 * _azar('$routeId alto mediodía');
  final valle = 12 + 10 * _azar('$routeId valle');
  return [
    for (var h = primeraHoraServicio; h <= _ultimaHora; h++)
      (valle +
              altoManana * campana(h.toDouble(), manana, anchoManana) +
              altoMediodia * campana(h.toDouble(), mediodia, 0.8) +
              altoTarde * campana(h.toDouble(), tarde, anchoTarde)) *
          (1 + 0.1 * _ruido('$routeId hora $h')),
  ];
}

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
  final forma = _forma(routeId);
  // Hay rutas que van más llenas que otras: 85 % a 110 % de la forma.
  final carga = 0.975 + 0.125 * _ruido('ruta $routeId');
  final local = desde.subtract(_bogota);
  final sumas = List.filled(forma.length, 0);
  final cuentas = List.filled(forma.length, 0);
  for (
    var dia = DateTime.utc(local.year, local.month, local.day);
    dia.add(_bogota).isBefore(hasta);
    dia = dia.add(const Duration(days: 1))
  ) {
    final dias = periodo.dias;
    if (dias.isNotEmpty && !dias.contains(dia.weekday)) continue;
    final fecha = '${dia.year}-${dia.month}-${dia.day}';
    // Sábado y domingo se mueve menos gente.
    final finde = dia.weekday >= DateTime.saturday ? 0.7 : 1.0;
    final delDia = finde * (1 + 0.08 * _ruido('$routeId $fecha'));
    for (var h = primeraHoraServicio; h <= _ultimaHora; h++) {
      final inicio = dia.add(_bogota).add(Duration(hours: h));
      final fin = inicio.add(const Duration(hours: 1));
      // Una hora cuenta cuando ya terminó: la de 3 a 4 sale después de las 4.
      if (fin.isAfter(hasta) || !fin.isAfter(desde)) continue;
      final i = h - primeraHoraServicio;
      for (final bus in buses) {
        final pct =
            forma[i] * carga * delDia + 12 * _ruido('$routeId $bus $fecha $h');
        sumas[i] += pct.round().clamp(0, 100);
        cuentas[i]++;
      }
    }
  }
  return [
    for (var i = 0; i < forma.length; i++)
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
