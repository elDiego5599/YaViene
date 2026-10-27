import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../utils/geo.dart';
import 'user_location_provider.dart';

/// Distancia del punto de espera a [bus] por su recorrido, como la mide el
/// aviso, hasta su paso más cerca; null si no se puede medir. La hoja y
/// Avisos la toman de aquí: medida en dos sitios, la hoja decía 13,4 km por
/// la ruta y Avisos 10 km en recta del mismo bus (dueño, 2026-10-16).
///
/// Un bus con aviso armado se mide desde el pin con el que se armó, no
/// desde el pin de ahora: es la misma referencia que usa el aviso para
/// decidir cuándo sonar, y verla cambiar al mover el pin hacía creer que el
/// aviso se había mudado con él.
///
/// Solo desde `build`: escucha al seguidor de la ruta, para que no se
/// deseche entre cuadros, y la ubicación, para que la cifra la siga.
double? distanciaAlBusDesdeTuPunto(WidgetRef ref, BusPosition bus) {
  final seguidor = ref.watch(seguidorRutaProvider(bus.routeId));
  final ancla = ref.read(proximityAlertsProvider.notifier).anchorFor(bus.busId);
  if (ancla != null) {
    return distanciaAlBus(seguidor, bus, ancla.$1, ancla.$2);
  }
  final location = ref.watch(userLocationProvider);
  if (!location.hasPosition) return null;
  return distanciaAlBus(seguidor, bus, location.lat!, location.lon!);
}
