import 'dart:math' as math;
import 'dart:ui';

import '../../../../core/theme/app_theme.dart';

/// La escala del video: verde donde casi no buscan, amarillo, naranja y el
/// rojo de los focos. Es continua: un foco pasa por todos los tonos hasta su
/// borde verde, como un mapa de calor de verdad. La usan el mapa, su tira de
/// horas y la ocupación: un solo idioma de color en Reportes.
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

/// Las horas sin búsquedas van en el gris del filo: se ve el hueco, pero no
/// se confunde con el verde de las horas con pocas búsquedas.
Color colorCalor(int count, int maxCount) {
  if (count <= 0 || maxCount <= 0) return AppColors.border;
  return colorEnEscala(count / maxCount);
}
