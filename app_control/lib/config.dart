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

  static const String _fallbackBackendUrl = String.fromEnvironment(
    'BACKEND_URL_FALLBACK',
    defaultValue: 'https://ya-viene-backend.fly.dev',
  );

  /// Dirección de respaldo, la misma idea que en la app del pasajero: si el
  /// túnel de siempre no contesta, el panel se va al despliegue de Fly en vez
  /// de quedarse sin flota.
  ///
  /// Pasa por el mismo filtro `esSegura` que la principal, y aquí importa más:
  /// por el respaldo viajarían la clave del panel y el token de toda la flota,
  /// y a diferencia de la principal —que revienta el arranque si no es
  /// https— este no puede reventar nada, porque es un camino que solo se pisa
  /// cuando ya algo va mal. Un respaldo inseguro simplemente no se usa.
  static String get fallbackBackendUrl {
    if (_fallbackBackendUrl.isEmpty) return '';
    if (kReleaseMode && !esSegura(_fallbackBackendUrl)) return '';
    return _fallbackBackendUrl;
  }

  static const String wsPath = '/ws';
}
