import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import 'fleet_providers.dart' show fleetApiProvider;

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

final reportesRutasProvider = FutureProvider.family<List<RutaBusquedas>, int?>((
  ref,
  hora,
) async {
  final token = ref.watch(authProvider).session?.token;
  final hasta = DateTime.now().toUtc();
  final data = await ref
      .watch(fleetApiProvider)
      .fetchSearchReports(
        token,
        desde: hasta.subtract(const Duration(days: 30)),
        hasta: hasta,
        hora: hora,
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
    FutureProvider.family<List<CeldaBusqueda>, ({String routeId, int? hora})>((
      ref,
      args,
    ) async {
      final token = ref.watch(authProvider).session?.token;
      final hasta = DateTime.now().toUtc();
      final data = await ref
          .watch(fleetApiProvider)
          .fetchSearchHeatmap(
            token,
            routeId: args.routeId,
            desde: hasta.subtract(const Duration(days: 30)),
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
