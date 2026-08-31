import 'package:flutter/foundation.dart' show kReleaseMode;

class AppConfig {
  static const String _backendUrl = String.fromEnvironment('BACKEND_URL');

  /// El panel lleva la clave del admin y, después, el token de toda la flota.
  /// Antes esto era una constante con `http://localhost:3000` de respaldo, y
  /// eso dejaba pasar dos cosas: un release compilado sin
  /// `--dart-define=BACKEND_URL=...` apuntaba en silencio a la propia máquina
  /// —el operador solo veía "no se pudo conectar", sin pista de por qué— y
  /// nada impedía compilar contra `http://`, que manda esa clave en claro por
  /// el wifi de la oficina. Ahora el arranque dice qué falta, igual que en la
  /// app del pasajero.
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
    if (kReleaseMode && !esSegura(_backendUrl)) {
      throw StateError(
        'BACKEND_URL debe ser https:// para no mandar la clave del panel en '
        'claro (recibido: $_backendUrl)',
      );
    }
    return _backendUrl;
  }

  /// `http://` solo vale contra la propia máquina, donde el tráfico no llega
  /// a salir a la red.
  static bool esSegura(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme == 'https') return true;
    return uri.scheme == 'http' &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '::1');
  }

  static const String wsPath = '/ws';
}
