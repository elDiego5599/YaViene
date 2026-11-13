// El viaje de puerta a puerta (docs/viaje-completo.md, sección 2): de un
// lugar a otro, a pie hasta donde se toma la ruta, en uno o dos buses y a
// pie hasta el destino.
import 'package:equatable/equatable.dart';

import '../lugares/lugar.dart';
import '../models/route_trajectory.dart';

/// Dónde se sube a una ruta o dónde se baja de ella.
///
/// No es un paradero: en Barranquilla el bus para donde se le pide, y este
/// es el punto de la ruta que deja la menor caminata.
class PuntoDeRuta extends Equatable {
  const PuntoDeRuta({
    required this.ruta,
    required this.avance,
    required this.punto,
    required this.caminata,
  });

  /// El `routeId` de la ruta.
  final String ruta;

  /// Metros por la ruta desde su inicio.
  final double avance;

  /// El punto, sobre la línea de la ruta.
  final GeoPoint punto;

  /// Metros a pie, en línea recta, para llegar aquí (si se sube) o desde
  /// aquí (si se baja).
  final double caminata;

  @override
  List<Object?> get props => [ruta, avance, punto, caminata];
}

/// Un pedazo del viaje: a pie o en bus.
sealed class Tramo extends Equatable {
  const Tramo();
}

/// Lo que se camina: del origen a la subida, de un bus a otro o de la
/// bajada al destino.
final class TramoAPie extends Tramo {
  const TramoAPie({
    required this.desde,
    required this.hasta,
    required this.metros,
  });

  final GeoPoint desde;
  final GeoPoint hasta;

  /// En línea recta: no hay red de calles para medir la caminata de
  /// verdad, y por eso se dice «unos».
  final double metros;

  @override
  List<Object?> get props => [desde, hasta, metros];
}

/// Lo que se anda en un bus, de la [subida] a la [bajada].
final class TramoEnBus extends Tramo {
  const TramoEnBus({
    required this.ruta,
    required this.empresa,
    required this.subida,
    required this.bajada,
    required this.metrosPorLaRuta,
  });

  /// El `routeId` de la ruta.
  final String ruta;

  /// El `companyId` de quien la opera: decide el color de su ficha.
  final String empresa;
  final PuntoDeRuta subida;
  final PuntoDeRuta bajada;

  /// Lo que anda el bus entre los dos puntos, en el sentido de la ruta.
  final double metrosPorLaRuta;

  @override
  List<Object?> get props => [ruta, empresa, subida, bajada, metrosPorLaRuta];
}

/// Una manera de ir de [origen] a [destino].
///
/// Los [tramos] van en orden y siempre empiezan y terminan a pie, aunque
/// sean cero metros: a pie, en bus y a pie; con cambio de bus, otro a pie
/// y otro en bus en medio.
class Viaje extends Equatable {
  const Viaje({
    required this.origen,
    required this.destino,
    required this.tramos,
  });

  final Lugar origen;
  final Lugar destino;
  final List<Tramo> tramos;

  /// Los tramos en bus, en el orden en que se toman.
  List<TramoEnBus> get enBus => tramos.whereType<TramoEnBus>().toList();

  /// Cuántos buses se toman: uno, o dos si hay cambio.
  int get buses => enBus.length;

  /// Todo lo que se camina, en metros.
  double get caminataTotal => tramos
      .whereType<TramoAPie>()
      .fold(0, (suma, tramo) => suma + tramo.metros);

  /// Todo lo que se anda en bus, en metros.
  double get metrosEnBus =>
      enBus.fold(0, (suma, tramo) => suma + tramo.metrosPorLaRuta);

  @override
  List<Object?> get props => [origen, destino, tramos];
}
