// Qué bus viene hacia donde se sube, y cuánto le falta por la ruta.
import 'package:equatable/equatable.dart';

import '../geo/por_ruta.dart';
import '../models/bus_position.dart';
import 'viaje.dart';

/// El bus que viene hacia la subida de un tramo. Se calcula con cada
/// posición que llega; no se guarda.
class BusQueViene extends Equatable {
  const BusQueViene({
    required this.busId,
    required this.metrosHastaLaSubida,
    required this.alDia,
  });

  final String busId;

  /// Lo que le falta por la ruta, en su sentido, para pasar por la subida.
  final double metrosHastaLaSubida;

  /// Falso si el bus está sin señal y esta es su última posición conocida.
  final bool alDia;

  @override
  List<Object?> get props => [busId, metrosHastaLaSubida, alDia];
}

/// Un bus a menos de esto después de la subida está en ella: su largo (12 m)
/// más el ruido del GPS. Sin esto, en una ruta circular el bus parado donde
/// se sube decía que le faltaba la vuelta entera.
const double _enLaSubida = 25;

/// De los [buses], el que primero pasa por la subida de [tramo]: el que
/// menos tiene por andar hasta ella en el sentido de la ruta. Null si
/// ninguno viene.
///
/// Un bus que ya pasó no se devuelve: en una ruta circular viene otra vez
/// tras la vuelta entera; en las demás, no viene. Los buses sin señal solo
/// cuentan si no hay ninguno con ella. [seguidor] es el de la ruta del
/// tramo.
BusQueViene? busQueViene(
  TramoEnBus tramo,
  Iterable<BusPosition> buses,
  SeguidorRuta seguidor,
) {
  BusQueViene? mejor;
  for (final bus in buses) {
    if (bus.routeId != tramo.ruta) continue;
    final avance = seguidor.avanceDe(bus);
    if (avance == null) continue;
    final subida = tramo.subida.avance;
    final pasado = seguidor.ruta.recorridoDirigido(subida, avance);
    final falta = pasado != null && pasado <= _enLaSubida
        ? 0.0
        : seguidor.ruta.recorridoDirigido(avance, subida);
    if (falta == null) continue;
    final viene = BusQueViene(
      busId: bus.busId,
      metrosHastaLaSubida: falta,
      alDia: !bus.isGhostBus,
    );
    if (mejor == null ||
        (viene.alDia && !mejor.alDia) ||
        (viene.alDia == mejor.alDia && falta < mejor.metrosHastaLaSubida)) {
      mejor = viene;
    }
  }
  return mejor;
}
