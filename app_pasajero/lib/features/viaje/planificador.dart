// «¿A dónde vas?»: los dos puntos del viaje, las opciones que salen de ahí
// y lo que dice cada una en vivo (docs/viaje-completo.md, sección 3.3).
//
// La geometría vive en el core (`planear`, `busQueViene`, `RitmoDeRuta`);
// aquí solo se conecta con lo que la app ya tiene: las rutas del asset, el
// catálogo del backend, la ubicación y los buses en vivo.
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../map/presentation/providers/tracking_providers.dart';
import '../map/presentation/providers/user_location_provider.dart';
import '../notifications/presentation/providers/abrir_aviso_provider.dart'
    show buscarRuta;

/// La red con las rutas del asset. Con el catálogo del backend, cada ruta
/// lleva su empresa y quedan solo las que tienen buses; sin él (sin red),
/// todas, sin empresa, y la ficha va en el azul de botón.
RedDeRutas armarRed(List<RutaSobusa> rutas, Map<String, String> empresas) {
  return RedDeRutas([
    for (final ruta in rutas)
      if (empresas.isEmpty || empresas.containsKey(ruta.routeId))
        if (RutaMedible.de(ruta.waypoints) case final medible?)
          RutaDeLaRed(
            id: ruta.routeId,
            empresa: empresas[ruta.routeId] ?? '',
            medible: medible,
          ),
  ]);
}

/// `routeId` → `companyId`, del catálogo del backend. Vacío si no responde:
/// el planificador sigue con las rutas del asset.
final empresaPorRutaProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  try {
    final empresas = await ref.watch(companiesProvider.future);
    final rutas = await Future.wait([
      for (final empresa in empresas)
        ref.watch(routesByCompanyProvider(empresa.id).future),
    ]);
    return {
      for (final deUna in rutas)
        for (final ruta in deUna) ruta.id: ruta.companyId,
    };
  } on Object {
    return const {};
  }
});

final redDeRutasProvider = FutureProvider.autoDispose<RedDeRutas>((ref) async {
  final rutas = await ref.watch(rutasSobusaProvider.future);
  final empresas = await ref.watch(empresaPorRutaProvider.future);
  return armarRed(rutas, empresas);
});

/// Los dos puntos y la opción que se está mirando.
class Planificacion extends Equatable {
  const Planificacion({this.origen, this.destino, this.elegida = 0});

  final Lugar? origen;
  final Lugar? destino;

  /// El índice, en el plan, de la opción que va dibujada en el mapa.
  final int elegida;

  @override
  List<Object?> get props => [origen, destino, elegida];
}

class Planificador extends StateNotifier<Planificacion> {
  Planificador(super.inicial);

  /// Cada punto nuevo es otro plan: se vuelve a la mejor opción.
  void ponerOrigen(Lugar lugar) =>
      state = Planificacion(origen: lugar, destino: state.destino);

  void ponerDestino(Lugar lugar) =>
      state = Planificacion(origen: state.origen, destino: lugar);

  /// El regreso: el mismo viaje al revés.
  void invertir() =>
      state = Planificacion(origen: state.destino, destino: state.origen);

  void elegir(int indice) => state = Planificacion(
      origen: state.origen, destino: state.destino, elegida: indice);
}

/// Arranca desde donde está la persona, tal como lo tiene el mapa: el GPS
/// o el pin. Se toma una vez, al abrir: el viaje no se replanea solo
/// mientras se camina.
final planificadorProvider =
    StateNotifierProvider.autoDispose<Planificador, Planificacion>((ref) {
  final ubicacion = ref.read(userLocationProvider);
  final desde = switch (ubicacion) {
    UserLocationState(:final lat?, :final lon?, mode: UserLocationMode.gps) =>
      Lugar(punto: GeoPoint(lat: lat, lon: lon), origen: OrigenLugar.gps),
    UserLocationState(
      :final lat?,
      :final lon?,
      mode: UserLocationMode.manual
    ) =>
      Lugar(punto: GeoPoint(lat: lat, lon: lon), origen: OrigenLugar.pin),
    _ => null,
  };
  return Planificador(Planificacion(origen: desde));
});

/// El plan de los dos puntos; null mientras falte alguno.
final planProvider = Provider.autoDispose<AsyncValue<Plan>?>((ref) {
  final (:origen, :destino) = ref.watch(planificadorProvider
      .select((p) => (origen: p.origen, destino: p.destino)));
  if (origen == null || destino == null) return null;
  return ref
      .watch(redDeRutasProvider)
      .whenData((red) => planear(origen, destino, red));
});

/// El bus que viene a la subida de [tramo], con cada posición que llega.
final busQueVieneProvider =
    Provider.autoDispose.family<BusQueViene?, TramoEnBus>((ref, tramo) {
  final buses = ref.watch(busPositionsSourceProvider(tramo.ruta)).valueOrNull;
  final seguidor = ref.watch(seguidorRutaProvider(tramo.ruta));
  if (buses == null || seguidor == null) return null;
  return busQueViene(tramo, buses, seguidor);
});

/// El ritmo de una ruta (D24): se alimenta con cada posición mientras
/// alguien la mire, y sin seis minutos vistos no dice nada.
final ritmoDeRutaProvider =
    Provider.autoDispose.family<RitmoDeRuta?, String>((ref, ruta) {
  final seguidor = ref.watch(seguidorRutaProvider(ruta));
  if (seguidor == null) return null;
  final ritmo = RitmoDeRuta(seguidor);
  ref.listen(busPositionsSourceProvider(ruta), (_, buses) {
    for (final bus in buses.valueOrNull ?? const <BusPosition>[]) {
      ritmo.ver(bus);
    }
  }, fireImmediately: true);
  return ritmo;
});

/// «Llega de 3:42 a 3:47 p. m.»: el [rango] contado desde [ahora]. El borde
/// de abajo se redondea hacia atrás y el de arriba hacia adelante, para no
/// prometer más de lo que se sabe; la mañana o la tarde se dice una vez si
/// los dos bordes caen en la misma.
String textoDeLlegada(DateTime ahora, RangoDeLlegada rango) {
  final desde = _minuto(ahora.add(rango.desde));
  var hasta = _minuto(ahora.add(rango.hasta));
  if (hasta.isBefore(ahora.add(rango.hasta))) {
    hasta = hasta.add(const Duration(minutes: 1));
  }
  if (!hasta.isAfter(desde)) hasta = desde.add(const Duration(minutes: 1));
  final mismaMitad = (desde.hour < 12) == (hasta.hour < 12);
  return mismaMitad
      ? 'Llega de ${_reloj(desde)} a ${_reloj(hasta)} ${_mitad(hasta)}'
      : 'Llega de ${_reloj(desde)} ${_mitad(desde)} a ${_reloj(hasta)} '
          '${_mitad(hasta)}';
}

DateTime _minuto(DateTime t) =>
    DateTime(t.year, t.month, t.day, t.hour, t.minute);

String _reloj(DateTime t) {
  final doce = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$doce:${t.minute.toString().padLeft(2, '0')}';
}

String _mitad(DateTime t) => t.hour < 12 ? 'a. m.' : 'p. m.';

/// «unos 300 m a pie»: la caminata como se dice (sección 3.3), de 50 en
/// 50 m porque se mide en recta y prometer metros exactos sería mentir;
/// desde 1 km, en km con una cifra decimal.
String caminataHablada(double metros) {
  if (metros <= 0) return 'sin caminar';
  final redondo = ((metros / 50).round() * 50).clamp(50, double.infinity);
  if (redondo < 1000) return 'unos ${redondo.round()} m a pie';
  final km = (metros / 1000)
      .toStringAsFixed(1)
      .replaceAll('.', ',')
      .replaceAll(RegExp(r',0$'), '');
  return 'unos $km km a pie';
}

/// «Ir» (sección 3.3): el mapa con la empresa y la ruta del primer bus del
/// [Viaje] y el pin en su subida, que es donde se toma la ruta. Devuelve
/// `false` sin tocar nada si la ruta ya no está en el catálogo o no hay red:
/// mejor quedarse en el planificador que dejar el mapa a medias.
final irAlViajeProvider =
    Provider<Future<bool> Function(Viaje)>((ref) => (viaje) async {
          final tramo = viaje.enBus.first;
          final encontrada = await buscarRuta(ref, tramo.ruta,
              companyId: tramo.empresa.isEmpty ? null : tramo.empresa);
          if (encontrada == null) return false;
          final (empresa, ruta) = encontrada;
          ref.read(selectedCompanyProvider.notifier).select(empresa);
          ref.read(selectedRouteProvider.notifier).select(ruta);
          final subida = tramo.subida.punto;
          ref
              .read(userLocationProvider.notifier)
              .setManualPin(subida.lat, subida.lon, ancla: subida);
          return true;
        });
