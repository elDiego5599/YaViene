import 'package:flutter/foundation.dart' show kReleaseMode;

class AppConfig {
  static const String _backendUrl = String.fromEnvironment('BACKEND_URL');

  /// Sin `--dart-define=BACKEND_URL=...` un build de release apuntaría en
  /// silencio a localhost y fallaría en el teléfono sin explicación: mejor
  /// que el propio arranque diga qué falta.
  static String get backendUrl {
    if (_backendUrl.isEmpty) {
      if (kReleaseMode) {
        throw StateError(
          'Falta BACKEND_URL: compila con '
          '--dart-define=BACKEND_URL=<url del backend>',
        );
      }
      return 'http://localhost:3000';
    }
    return _backendUrl;
  }

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
  static const String fallbackBackendUrl = String.fromEnvironment(
    'BACKEND_URL_FALLBACK',
    defaultValue: 'https://ya-viene-backend.fly.dev',
  );

  static const String wsPath = '/ws';
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );
}
