import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;
import 'package:ya_viene_core/ya_viene_core.dart' show esUrlSegura;

class AppConfig {
  static const String _backendUrl = String.fromEnvironment('BACKEND_URL');

  /// Sin `--dart-define=BACKEND_URL=...` un build de release apuntaría en
  /// silencio a localhost y fallaría en el teléfono sin explicación: mejor
  /// que el propio arranque diga qué falta.
  static String get backendUrl =>
      backendUrlPara(_backendUrl, release: kReleaseMode);

  /// La regla de `backendUrl`, con el modo a la vista para poder probarla
  /// (`kReleaseMode` es falso en toda prueba). En release tampoco vale
  /// `http://` remoto: mandaría en claro el token de los avisos y el punto
  /// donde espera el pasajero (AUD29-19), igual que el panel no deja ir su
  /// clave.
  @visibleForTesting
  static String backendUrlPara(String definida, {required bool release}) {
    if (definida.isEmpty) {
      if (release) {
        throw StateError(
          'Falta BACKEND_URL: compila con '
          '--dart-define=BACKEND_URL=<url del backend>',
        );
      }
      return 'http://localhost:3000';
    }
    if (release && !esUrlSegura(definida)) {
      throw StateError(
        'BACKEND_URL debe ser https:// para no mandar en claro el token de '
        'los avisos ni el punto del pasajero (recibido: $definida)',
      );
    }
    return definida;
  }

  static const String _fallbackBackendUrl = String.fromEnvironment(
    'BACKEND_URL_FALLBACK',
    defaultValue: 'https://ya-viene-backend.fly.dev',
  );

  /// Dirección de respaldo, para cuando la principal no contesta.
  ///
  /// `BACKEND_URL` es una constante de compilación, así que una APK ya
  /// repartida apunta a un único sitio para toda su vida. El sitio de siempre
  /// es un túnel de ngrok que corre en un portátil: si se cae en mitad de una
  /// demo, sin esto no queda más salida que recompilar y volver a instalar.
  ///
  /// El valor por defecto es el despliegue de Fly, que existe justo para esto
  /// y duerme mientras no se use (la primera petición lo levanta). Viene
  /// puesto de fábrica y no hace falta pasar nada al compilar; se sobrescribe
  /// con `--dart-define=BACKEND_URL_FALLBACK=...`, y con la cadena vacía se
  /// desactiva el respaldo.
  ///
  /// Quién decide entre las dos es `BackendResolver`, en el arranque.
  static String get fallbackBackendUrl =>
      respaldoPara(_fallbackBackendUrl, release: kReleaseMode);

  /// El respaldo pasa por el mismo filtro que la principal, pero no revienta
  /// el arranque: es un camino que solo se pisa cuando ya algo va mal. Un
  /// respaldo inseguro simplemente no se usa.
  @visibleForTesting
  static String respaldoPara(String definido, {required bool release}) {
    if (release && !esUrlSegura(definido)) return '';
    return definido;
  }

  static const String wsPath = '/ws';
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );
}
