import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/services/bus_notification_service.dart';
import '../../../map/presentation/providers/map_view_state.dart';
import '../../../map/presentation/providers/selected_buses_provider.dart';

/// Tocar un aviso deja el mapa como estaba cuando sonó: su empresa, su ruta
/// y su bus, con la cámara encima del bus. Antes abría la app sin más y
/// había que volver a escoger empresa y ruta para verlo (dueño, 2026-10-02).
///
/// El aviso solo trae el bus y la ruta, así que la empresa se busca entre
/// las rutas de cada una, empezando por la que ya estaba escogida. Devuelve
/// `false` sin tocar nada si la ruta ya no existe o no hay red: el mapa se
/// queda como estaba, que es lo que hacía tocar el aviso hasta ahora.
final abrirAvisoProvider =
    Provider<Future<bool> Function(AvisoTocado)>((ref) => (aviso) async {
          final encontrada = await _buscarRuta(ref, aviso.routeId);
          if (encontrada == null) return false;
          final (empresa, ruta) = encontrada;
          // La empresa antes que la ruta, que es como las escoge el
          // selector; la ruta suelta el bus anterior y luego se toma este.
          ref.read(selectedCompanyProvider.notifier).select(empresa);
          ref.read(selectedRouteProvider.notifier).select(ruta);
          if (!ref.read(selectedBusesProvider).contains(aviso.busId)) {
            ref.read(selectedBusesProvider.notifier).toggleBus(aviso.busId);
          }
          ref.read(enfoqueDeBusProvider.notifier).pedir(aviso.busId, ruta.id);
          return true;
        });

Future<(Company, RouteInfo)?> _buscarRuta(Ref ref, String routeId) async {
  final empresa = ref.read(selectedCompanyProvider);
  final ruta = ref.read(selectedRouteProvider);
  if (empresa != null && ruta?.id == routeId) return (empresa, ruta!);
  try {
    final empresas = await _leer(ref, companiesProvider.future);
    final enOrden = [
      ...empresas.where((e) => e.id == empresa?.id),
      ...empresas.where((e) => e.id != empresa?.id),
    ];
    for (final e in enOrden) {
      final rutas = await _leer(ref, routesByCompanyProvider(e.id).future);
      for (final r in rutas) {
        if (r.id == routeId) return (e, r);
      }
    }
  } catch (e) {
    debugPrint('aviso: no se pudo encontrar la ruta $routeId: $e');
  }
  return null;
}

/// Lee un proveedor que se desecha solo sin que se deseche a mitad de la
/// lectura: nadie más lo mira mientras se busca la ruta.
Future<T> _leer<T>(Ref ref, ProviderListenable<Future<T>> proveedor) async {
  final suscripcion = ref.listen(proveedor, (_, __) {});
  try {
    return await suscripcion.read();
  } finally {
    suscripcion.close();
  }
}
