/// Cómo se escribe una distancia, en un solo sitio (T6.8).
///
/// Las reglas son las del glosario (`ya_viene_core/lib/core/texto/
/// glosario.json`, `distancia`): distancia, nunca ETA; metros enteros bajo
/// 1 km, un decimal con coma desde 1 km y sin decimales desde 10 km. La hoja,
/// el historial y la notificación las toman de aquí; `glosario_test.dart`
/// las ata al glosario.
library;

/// Mismo formato que la métrica grande de la hoja ("3,4 km"), sin decimal a
/// partir de 10 km, donde el decimal ya no dice nada. Con coma, como se
/// escribe el decimal en español y como lo dice la voz (_metricSpoken).
/// La landing escribe igual.
///
/// Público porque el estado vacío de la hoja dice lo mismo con otras
/// palabras: las dos pantallas tienen que cantar la misma distancia.
String kmLabel(double meters) {
  final km = meters / 1000;
  return km >= 10
      ? '${km.round()} km'
      : '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// La distancia de un aviso: metros hasta 999 y luego como la hoja
/// («3,4 km», «14 km»). En metros crudos, «14408 m» partía la franja en
/// dos filas en un iPhone (dueño, 2026-10-01).
String distanciaAviso(int metros) =>
    metros < 1000 ? '$metros m' : kmLabel(metros.toDouble());
