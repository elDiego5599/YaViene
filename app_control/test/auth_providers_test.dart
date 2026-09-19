import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ya_viene_control/features/auth/data/auth_api.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({
    this.loginResult,
    this.loginError,
    this.validateResult,
    this.validateThrows,
  }) : super(baseUrl: 'http://localhost:3000');

  final AuthSession? loginResult;
  final AuthApiException? loginError;
  final bool? validateResult;
  final Object? validateThrows;

  /// Los tokens con los que se pidió cerrar sesión en el servidor.
  final List<String> cierres = [];

  @override
  Future<AuthSession> login(String username, String password) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<bool> validateSession(String token) async {
    if (validateThrows != null) throw validateThrows!;
    return validateResult!;
  }

  @override
  Future<void> logout(String token) async => cierres.add(token);
}

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? initialValues])
    : _values = {...?initialValues};

  final Map<String, String> _values;

  /// Cuando el almacén del sistema se niega. En Windows es un archivo cifrado
  /// con la clave del usuario y en macOS el Llavero: los dos pueden fallar por
  /// permisos o por política de la máquina, y hasta ahora ninguna prueba lo
  /// cubría porque este doble siempre respondía que sí.
  bool falla = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (falla) throw Exception('almacén del sistema no disponible');
    return _values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (falla) throw Exception('almacén del sistema no disponible');
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (falla) throw Exception('almacén del sistema no disponible');
    _values.remove(key);
  }
}

void main() {
  const session = AuthSession(
    token: 't-1',
    companyId: 'c-1',
    companyName: 'Empresa 1',
  );

  test('login exitoso deja el estado autenticado y guarda la sesión', () async {
    final storage = _FakeSecureStorage();
    final notifier = AuthNotifier(
      api: _FakeAuthApi(loginResult: session),
      storage: storage,
    );

    final ok = await notifier.login('admin', 'admin123');

    expect(ok, true);
    expect(notifier.state.status, AuthStatus.authenticated);
    expect(notifier.state.session?.token, 't-1');
    expect(notifier.state.error, null);
    expect(await storage.read(key: 'auth_token'), 't-1');
  });

  test(
    'login con credenciales incorrectas deja el mensaje de error, sin sesión',
    () async {
      final notifier = AuthNotifier(
        api: _FakeAuthApi(
          loginError: const AuthApiException(
            'Usuario o contraseña incorrectos.',
          ),
        ),
        storage: _FakeSecureStorage(),
      );

      final ok = await notifier.login('admin', 'mala-clave');

      expect(ok, false);
      expect(notifier.state.status, AuthStatus.unknown);
      expect(notifier.state.error, 'Usuario o contraseña incorrectos.');
      expect(notifier.state.loading, false);
    },
  );

  test(
    'restoreSession con token guardado y válido entra autenticado',
    () async {
      final storage = _FakeSecureStorage({
        'auth_token': 't-1',
        'auth_company_id': 'c-1',
        'auth_company_name': 'Empresa 1',
      });
      final notifier = AuthNotifier(
        api: _FakeAuthApi(validateResult: true),
        storage: storage,
      );

      await notifier.restoreSession();

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.session?.companyId, 'c-1');
    },
  );

  test(
    'restoreSession con token rechazado por el backend limpia la sesión guardada',
    () async {
      final storage = _FakeSecureStorage({
        'auth_token': 't-1',
        'auth_company_id': 'c-1',
        'auth_company_name': 'Empresa 1',
      });
      final notifier = AuthNotifier(
        api: _FakeAuthApi(validateResult: false),
        storage: storage,
      );

      await notifier.restoreSession();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(await storage.read(key: 'auth_token'), null);
    },
  );

  test(
    'restoreSession sin red mantiene la sesión guardada (el dashboard reintentará)',
    () async {
      final storage = _FakeSecureStorage({
        'auth_token': 't-1',
        'auth_company_id': 'c-1',
        'auth_company_name': 'Empresa 1',
      });
      final notifier = AuthNotifier(
        api: _FakeAuthApi(validateThrows: Exception('sin red')),
        storage: storage,
      );

      await notifier.restoreSession();

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.session?.token, 't-1');
    },
  );

  test('restoreSession sin nada guardado deja no autenticado', () async {
    final notifier = AuthNotifier(
      api: _FakeAuthApi(),
      storage: _FakeSecureStorage(),
    );

    await notifier.restoreSession();

    expect(notifier.state.status, AuthStatus.unauthenticated);
    expect(notifier.state.session, null);
  });

  // El fallo que llegó a manos del usuario: el servidor contestaba 200 y el
  // panel lo rechazaba con "No se pudo conectar con el servidor", porque las
  // escrituras al almacén del sistema iban dentro del mismo try que la red.
  test('si el almacén del sistema falla, se entra igual y sin error', () async {
    final storage = _FakeSecureStorage()..falla = true;
    final notifier = AuthNotifier(
      api: _FakeAuthApi(loginResult: session),
      storage: storage,
    );

    final ok = await notifier.login('admin', 'clave-buena');

    expect(ok, true);
    expect(notifier.state.status, AuthStatus.authenticated);
    expect(notifier.state.session?.token, 't-1');
    expect(notifier.state.error, null);
  });

  test(
    'si el almacén del sistema falla, restoreSession deja no autenticado',
    () async {
      final storage = _FakeSecureStorage({'auth_token': 't-1'})..falla = true;
      final notifier = AuthNotifier(api: _FakeAuthApi(), storage: storage);

      await notifier.restoreSession();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.session, null);
    },
  );

  test('logout no se atasca si el almacén del sistema falla', () async {
    final storage = _FakeSecureStorage({'auth_token': 't-1'})..falla = true;
    final notifier = AuthNotifier(api: _FakeAuthApi(), storage: storage);

    await notifier.logout();

    expect(notifier.state.status, AuthStatus.unauthenticated);
  });

  // Cerrar sesión solo en el equipo dejaba vivo el token para quien lo
  // hubiera copiado: ahora el servidor lo revoca y luego se borra aquí.
  test('logout pide al servidor revocar el token y borra la sesión', () async {
    final storage = _FakeSecureStorage({
      'auth_token': 't-1',
      'auth_company_id': 'c-1',
      'auth_company_name': 'Empresa 1',
    });
    final api = _FakeAuthApi(loginResult: session);
    final notifier = AuthNotifier(api: api, storage: storage);
    await notifier.login('admin', 'clave-buena');

    await notifier.logout();

    expect(api.cierres, ['t-1']);
    expect(notifier.state.status, AuthStatus.unauthenticated);
    expect(await storage.read(key: 'auth_token'), null);
  });

  test('logout sin sesión no llama al servidor', () async {
    final api = _FakeAuthApi();
    final notifier = AuthNotifier(api: api, storage: _FakeSecureStorage());

    await notifier.logout();

    expect(api.cierres, isEmpty);
    expect(notifier.state.status, AuthStatus.unauthenticated);
  });

  group('AuthApi.logout contra un servidor', () {
    late HttpServer servidor;
    final pedidos = <String>[];
    var estado = HttpStatus.noContent;

    setUp(() async {
      pedidos.clear();
      estado = HttpStatus.noContent;
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      servidor.listen((req) async {
        pedidos.add(
          '${req.method} ${req.uri.path} '
          '${req.headers.value(HttpHeaders.authorizationHeader)}',
        );
        req.response.statusCode = estado;
        if (estado != HttpStatus.noContent) {
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({
              'error': {'code': 'X'},
            }),
          );
        }
        await req.response.close();
      });
    });

    tearDown(() => servidor.close(force: true));

    String base() => 'http://127.0.0.1:${servidor.port}';

    test('manda POST /api/fleet/logout con el token', () async {
      await AuthApi(baseUrl: base()).logout('t-1');

      expect(pedidos, ['POST /api/fleet/logout Bearer t-1']);
    });

    // Un token que el servidor ya no reconoce (caducado, contraseña
    // cambiada) no tiene nada que revocar: la sesión local se borra igual.
    test('un 401 no lanza', () async {
      estado = HttpStatus.unauthorized;

      await AuthApi(baseUrl: base()).logout('t-1');

      expect(pedidos, hasLength(1));
    });

    // Un servidor que acepta y no contesta es la red que se cuelga: la
    // salida no espera los 8 s del cliente.
    test('un servidor mudo no retiene más de 3 s', () async {
      final mudo = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final abiertos = <Socket>[];
      mudo.listen(abiertos.add);
      final reloj = Stopwatch()..start();

      await AuthApi(baseUrl: 'http://127.0.0.1:${mudo.port}').logout('t-1');

      expect(reloj.elapsed, lessThan(const Duration(seconds: 4)));
      for (final s in abiertos) {
        s.destroy();
      }
      await mudo.close();
    });

    test('sin servidor no lanza', () async {
      final puerto = servidor.port;
      await servidor.close(force: true);

      await AuthApi(baseUrl: 'http://127.0.0.1:$puerto').logout('t-1');
    });
  });
}
