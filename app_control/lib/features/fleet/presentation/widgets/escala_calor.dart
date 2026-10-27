import 'dart:ui';

import 'package:ya_viene_core/ya_viene_core.dart' show colorEnEscala;

import '../../../../core/theme/app_theme.dart';

// La escala vive en el core: la ocupación del pasajero usa la misma.
export 'package:ya_viene_core/ya_viene_core.dart'
    show coloresCalor, colorEnEscala;

/// Las horas sin búsquedas van en el gris del filo: se ve el hueco, pero no
/// se confunde con el verde de las horas con pocas búsquedas.
Color colorCalor(int count, int maxCount) {
  if (count <= 0 || maxCount <= 0) return AppColors.border;
  return colorEnEscala(count / maxCount);
}
