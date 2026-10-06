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
/// escribe el decimal en español y como lo dice la voz ([distanciaHablada]).
/// La landing escribe igual.
///
/// Público porque el estado vacío de la hoja dice lo mismo con otras
/// palabras: las dos pantallas tienen que cantar la misma distancia.
String kmLabel(double meters) {
  final km = meters / 1000;
  final unDecimal = km.toStringAsFixed(1);
  // Se decide con la cifra ya redondeada: 9.960 m con un decimal son
  // «10,0», y desde 10 km va sin decimal.
  return double.parse(unDecimal) >= 10
      ? '${km.round()} km'
      : '${unDecimal.replaceAll('.', ',')} km';
}

/// Bajo 1 km la distancia va en metros enteros. Se decide con los metros ya
/// redondeados: 999,6 m se escribirían «1000 m», que es 1 km con otro
/// nombre, y la cifra saltaría de «1000» a «1,0» sin moverse el bus.
bool enMetros(double meters) => meters.round() < 1000;

/// La distancia de un aviso: metros hasta 999 y luego como la hoja
/// («3,4 km», «14 km»). En metros crudos, «14408 m» partía la franja en
/// dos filas en un iPhone (dueño, 2026-10-01).
String distanciaAviso(int metros) =>
    enMetros(metros.toDouble()) ? '$metros m' : kmLabel(metros.toDouble());

/// La cifra grande de la hoja y su unidad: ("850", "m de ti") o
/// ("1,4", "km de tu pin anterior"). A diferencia de [kmLabel], la hoja
/// conserva el decimal pasados 10 km. [referencia] dice desde dónde se mide:
/// "de ti" o "de tu pin anterior".
(String, String) distanciaPartes(double meters, String referencia) {
  if (enMetros(meters)) return ('${meters.round()}', 'm $referencia');
  final km = (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return (km, 'km $referencia');
}

/// La misma distancia, dicha entera y en castellano.
///
/// En pantalla la unidad va abreviada porque debajo del número se lee
/// sola; en voz alta "m" es una letra suelta y el punto decimal se
/// pronuncia "punto".
String distanciaHablada(double meters, String referencia) {
  final (cifra, _) = distanciaPartes(meters, referencia);
  if (enMetros(meters)) {
    return 'A $cifra ${cifra == '1' ? 'metro' : 'metros'} $referencia';
  }
  return 'A $cifra kilómetros $referencia';
}
