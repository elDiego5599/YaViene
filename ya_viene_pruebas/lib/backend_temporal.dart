import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Un backend de usar y tirar para los simulacros (T10.5 b y d).
///
/// Arranca `YaVieneBackend` desde su código, en puertos libres y sobre una
/// base temporal que se borra al [parar]: el backend vivo, su base y el túnel
/// no se tocan. Los secretos (JWT, clave del admin, PIN de la flota) se
/// inventan en cada corrida y mueren con ella; la cuenta de prueba del dueño
/// no entra aquí.
///
/// La flota demo va encendida: sus simuladores publican por MQTT como un
/// equipo GPS de verdad, que es lo que el pasajero y el panel tienen que
/// volver a ver después de un reinicio.
///
/// El backend se busca al lado de este repo (`../../YaVieneBackend` desde el
/// paquete que corre la prueba); `YAVIENE_BACKEND` lo cambia. Sin él, o sin
/// `node`, [buscar] devuelve `null` y la prueba se salta.
class BackendTemporal {
  BackendTemporal._(this._dir, this._tmp, this._entorno, this.url);

  final String _dir;
  final Directory _tmp;
  final Map<String, String> _entorno;

  /// `http://127.0.0.1:<puerto>`.
  final String url;
  Process? _proceso;

  /// La base de esta corrida, la que `check-demo.sh` lee con `DB=`.
  String get rutaBase => _entorno['YA_VIENE_DB_PATH']!;

  /// La clave del admin de esta corrida (la pide `/api/admin/login`).
  String get claveApi => _entorno['ADMIN_API_KEY']!;

  /// La carpeta de YaVieneBackend, o `null` si no está al lado.
  static String? buscar() {
    final dir = Platform.environment['YAVIENE_BACKEND'] ??
        '${Directory.current.path}/../../YaVieneBackend';
    return File('$dir/src/index.ts').existsSync()
        ? Directory(dir).absolute.path
        : null;
  }

  /// Prepara la base temporal y arranca el backend.
  ///
  /// [revisionPanelMs] es cada cuánto el backend revisa los paneles
  /// conectados; sin él, el de producción (un minuto), que es el que el
  /// simulacro d tiene que cronometrar.
  static Future<BackendTemporal> arrancar(
    String dir, {
    int? revisionPanelMs,
  }) async {
    final tmp = await Directory.systemTemp.createTemp('yaviene-simulacro-');
    final http = await _puertoLibre();
    final mqtt = await _puertoLibre();
    final entorno = <String, String>{
      ...Platform.environment,
      'YA_VIENE_DB_PATH': '${tmp.path}/simulacro.db',
      'HTTP_HOST': '127.0.0.1',
      'HTTP_PORT': '$http',
      'MQTT_PORT': '$mqtt',
      'JWT_SECRET': _azar(32),
      'ADMIN_API_KEY': _azar(24),
      'PIN': '${100000 + Random.secure().nextInt(900000)}',
      'YA_VIENE_SEED_DEMO': '1',
      'YA_VIENE_FLOTA_DEMO': '1',
      'MQTT_DEBUG_LOGS': 'false',
      if (revisionPanelMs != null)
        'YA_VIENE_REVISION_PANEL_MS': '$revisionPanelMs',
    }
      // Un `local.env` exportado en la consola volvería este backend uno
      // «expuesto» y exigiría secretos de producción; aquí no hay nada que
      // exponer.
      ..remove('YA_VIENE_EXPUESTO')
      ..remove('NODE_ENV');
    final backend =
        BackendTemporal._(dir, tmp, entorno, 'http://127.0.0.1:$http');
    await backend._levantar();
    return backend;
  }

  Future<void> _levantar() async {
    final proceso = await Process.start(
      'node',
      ['--import', 'tsx', 'src/index.ts'],
      workingDirectory: _dir,
      environment: _entorno,
      includeParentEnvironment: false,
    );
    // Sin leerlos, los búferes de salida se llenan y el backend se traba.
    proceso.stdout.drain<void>();
    proceso.stderr.drain<void>();
    _proceso = proceso;
    final limite = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(limite)) {
      if (await _listo()) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw StateError('el backend temporal no arrancó en 30 s');
  }

  Future<bool> _listo() async {
    try {
      final r = await _pedir('GET', '/api/ready');
      return r.$1 == 200;
    } on Object {
      return false;
    }
  }

  /// Simulacro b: para el backend como lo para launchd (SIGTERM, apagado
  /// ordenado) y lo vuelve a levantar con la misma base y los mismos puertos.
  Future<void> reiniciar() async {
    await _matar();
    await _levantar();
  }

  Future<void> _matar() async {
    final proceso = _proceso;
    if (proceso == null) return;
    _proceso = null;
    proceso.kill(ProcessSignal.sigterm);
    await proceso.exitCode.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        proceso.kill(ProcessSignal.sigkill);
        return proceso.exitCode;
      },
    );
  }

  /// Crea —o, si ya existe, cambia la contraseña de— un admin de empresa,
  /// con el mismo script que usa el dueño. Cambiarla sube la versión del
  /// token y deja sin valor los ya emitidos (T3.1).
  Future<void> guardarAdmin(
    String empresa,
    String usuario,
    String contrasena,
  ) async {
    // Una lectura cualquiera abre la base y crea las tablas: el backend no
    // la toca hasta que alguien se la pide.
    await _pedir('GET', '/api/companies');
    final r = await Process.run(
      'node',
      ['scripts/crear-admin-empresa.mjs', empresa, usuario, '-', 'Simulacro'],
      workingDirectory: _dir,
      // La contraseña por el entorno y no por el argumento (P3-3).
      environment: {..._entorno, 'CLAVE_PANEL': contrasena},
      includeParentEnvironment: false,
    );
    if (r.exitCode != 0) {
      throw StateError('crear-admin-empresa falló: ${r.stderr}');
    }
  }

  /// El token del panel para [usuario], como lo pide la pantalla de entrada.
  Future<String> entrar(String usuario, String contrasena) async {
    final r = await _pedir('POST', '/api/admin/login', {
      'username': usuario,
      'password': contrasena,
      'apiKey': claveApi,
    });
    final token = (jsonDecode(r.$2) as Map)['token'];
    if (token is! String) throw StateError('login falló: ${r.$2}');
    return token;
  }

  /// Para el backend y borra su base.
  Future<void> parar() async {
    await _matar();
    if (_tmp.existsSync()) _tmp.deleteSync(recursive: true);
  }

  Future<(int, String)> _pedir(
    String metodo,
    String ruta, [
    Object? cuerpo,
  ]) async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await cliente.openUrl(metodo, Uri.parse('$url$ruta'));
      if (cuerpo != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(cuerpo));
      }
      final res = await req.close();
      return (res.statusCode, await res.transform(utf8.decoder).join());
    } finally {
      cliente.close(force: true);
    }
  }

  static Future<int> _puertoLibre() async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final puerto = s.port;
    await s.close();
    return puerto;
  }

  static String _azar(int bytes) {
    final r = Random.secure();
    return List.generate(bytes, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
