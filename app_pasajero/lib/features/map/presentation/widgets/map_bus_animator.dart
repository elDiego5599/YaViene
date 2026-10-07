// Rumbo de los buses del pasajero. El tramo animado (`BusMotion` y
// `displayOf`) vive en el core: lo comparte el mapa del panel.
import 'package:ya_viene_core/ya_viene_core.dart';

/// Una posición sin rumbo se queda con el de la anterior del mismo bus. El
/// backend guarda NULL cuando el bus no lo manda o lo manda fuera de rango, y
/// pintarlo como 0 giraba el bus hacia el norte en cada paquete.
BusPosition conRumboAnterior(BusPosition nueva, BusPosition? anterior) {
  final rumbo = anterior?.heading;
  if (nueva.heading != null || rumbo == null) return nueva;
  return nueva.copyWith(heading: rumbo);
}
