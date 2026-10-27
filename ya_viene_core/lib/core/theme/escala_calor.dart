import 'dart:math' as math;
import 'dart:ui';

/// La escala del video: verde donde casi no buscan, amarillo, naranja y el
/// rojo de los focos. Es continua: un foco pasa por todos los tonos hasta su
/// borde verde, como un mapa de calor de verdad. La usan el mapa, su tira de
/// horas y la ocupación del panel, y la ocupación de la tarjeta del bus del
/// pasajero: un solo idioma de color para lo lleno.
const coloresCalor = [
  Color(0xFF7CC04A),
  Color(0xFFF4C430),
  Color(0xFFF28B2C),
  Color(0xFFE24B4A),
];

/// El tono de [coloresCalor] para `t` de 0 (verde) a 1 (rojo), sin saltos.
Color colorEnEscala(double t) {
  final x = t.clamp(0.0, 1.0) * (coloresCalor.length - 1);
  final i = math.min(x.floor(), coloresCalor.length - 2);
  return Color.lerp(coloresCalor[i], coloresCalor[i + 1], x - i)!;
}
