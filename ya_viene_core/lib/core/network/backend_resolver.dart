import 'dart:convert';

import 'package:http/http.dart' as http;

/// Elige contra qué backend habla la app: el de siempre, o el de respaldo.
///
/// La dirección del backend es una constante de compilación
/// (`String.fromEnvironment`), así que hasta ahora una APK ya repartida
/// apuntaba a un único sitio para toda su vida. Si ese sitio se caía —y el de
/// siempre es un túnel de ngrok que corre en un portátil— no había nada que
/// hacer salvo recompilar y volver a instalar. Eso, el día de una demo, no es
/// un plan.
///
/// Aquí la app pregunta antes de arrancar: si la principal contesta, se usa
/// esa y no cambia nada; si no contesta, se prueba la de respaldo. Solo se
/// cambia de sitio cuando la principal falla de verdad, para que en el caso
/// normal —que es el 99 % de los arranques— esto no sea más que una petición
/// de más.
///
/// Cuando ninguna de las dos responde se devuelve la principal a propósito:
/// así los mensajes de error que ve el usuario siguen hablando del sitio que
/// se configuró, y no de un respaldo que él no sabe que existe.
class BackendResolver {
  const BackendResolver._();

  /// Ruta que se consulta para saber si un backend está vivo. Es la misma que
  /// usa `check-demo.sh` y la misma que mira el chequeo de salud de Fly.
  static const String rutaSalud = '/api/health';

  /// Espera para la principal. Corta: si el túnel está caído, lo normal es que
  /// la conexión ni siquiera se establezca, y este tiempo es el que el usuario
  /// pasa mirando una pantalla en blanco antes de que se resuelva por el
  /// respaldo.
  static const Duration esperaPrincipal = Duration(seconds: 3);

  /// Espera para el respaldo. Larga porque la máquina de Fly duerme cuando no
  /// se usa y la primera petición la levanta: medido, ese arranque en frío
  /// tarda unos 8 segundos.
  static const Duration esperaRespaldo = Duration(seconds: 20);

  /// Devuelve la URL base que la app debe usar.
  ///
  /// [sonda] existe para las pruebas: por defecto pregunta de verdad por HTTP.
  static Future<String> resolver({
    required String principal,
    required String respaldo,
    Duration tiempoPrincipal = esperaPrincipal,
    Duration tiempoRespaldo = esperaRespaldo,
    Future<bool> Function(String url, Duration espera)? sonda,
  }) async {
    final preguntar = sonda ?? responde;

    // Sin respaldo distinto no hay nada que decidir, y preguntar sería una
    // espera regalada en el arranque.
    if (respaldo.isEmpty || respaldo == principal) return principal;

    if (await preguntar(principal, tiempoPrincipal)) return principal;
    if (await preguntar(respaldo, tiempoRespaldo)) return respaldo;
    return principal;
  }

  /// ¿Contesta este backend? Se exige que la respuesta sea el JSON de salud y
  /// no solo un 200: un túnel caído suele devolver la página de error del
  /// proveedor, que también es 200 y dejaría pasar un backend muerto.
  static Future<bool> responde(String url, Duration espera) async {
    try {
      final respuesta = await http
          .get(Uri.parse('$url$rutaSalud'))
          .timeout(espera);
      if (respuesta.statusCode != 200) return false;
      final cuerpo = jsonDecode(respuesta.body);
      return cuerpo is Map && cuerpo['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }
}
