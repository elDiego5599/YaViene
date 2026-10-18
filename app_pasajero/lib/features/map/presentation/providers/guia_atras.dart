import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'map_tour_provider.dart';
import 'map_view_state.dart';
import 'selected_buses_provider.dart';
import 'user_location_provider.dart';

/// Lo que comparten `ref.read` de un widget, de un provider y del
/// contenedor de las pruebas.
typedef LeerProvider = T Function<T>(ProviderListenable<T> provider);

/// El paso al que lleva «Atrás» desde [paso], o null si no hay ninguno.
///
/// Con el punto de espera ya puesto no se vuelve a «Fija tu punto»: la
/// siguiente lectura del GPS lo daba por hecho, la guía rebotaba a la
/// búsqueda y «Atrás» parecía no hacer nada.
MapGuideStep? pasoAnterior(
  MapGuideState guia,
  MapGuideStep paso, {
  required bool hayPunto,
}) {
  if (paso.index == 0) return null;
  final anterior = MapGuideStep.values[paso.index - 1];
  if (anterior == MapGuideStep.location &&
      (!guia.includesLocation || hayPunto)) {
    return null;
  }
  return anterior;
}

/// «Atrás» en la guía: vuelve un paso y deshace lo que ese paso dejó hecho,
/// para que se pueda repetir. Solo cambiar el número de paso dejaba la
/// pantalla como estaba: el bus seguía elegido en «Toca un bus» (tocarlo lo
/// soltaba) y «Muestra los buses» quedaba dentro de un selector cerrado.
Future<void> volverEnGuia(LeerProvider leer, MapGuideStep paso) async {
  final anterior = pasoAnterior(
    leer(mapGuideProvider),
    paso,
    hayPunto: leer(userLocationProvider).hasPosition,
  );
  if (anterior == null) return;
  if (anterior == MapGuideStep.buses) {
    leer(selectedBusesProvider.notifier).clear();
  }
  await leer(mapGuideProvider.notifier).moveTo(anterior);
  if (anterior == MapGuideStep.launchBuses) {
    leer(pedirSelectorProvider.notifier).state++;
  }
}
