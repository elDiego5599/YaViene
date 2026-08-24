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

  static const String wsPath = '/ws';
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );
}
