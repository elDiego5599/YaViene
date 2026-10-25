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
    this.sesionActualResult,
    this.sesionActualThrows,
    this.renovarResult,
    this.renovarError,
  }) : super(baseUrl: 'http://localhost:3000');

  final AuthSession? loginResult;
  final AuthApiException? loginError;
  final bool? validateResult;
  final AuthSession? sesionActualResult;
  final Object? sesionActualThrows;
  final AuthSession? renovarResult;
  final Object? renovarError;
  final tokensRenovados = <String>[];

  /// Los tokens con los que se pidió cerrar sesión en el servidor (null: la
  /// cookie del panel web).
  final List<String?> cierres = [];

  @override
  Future<AuthSession> login(String username, String password) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<bool> validateSession(String token) async => validateResult!;

  @override
  Future<AuthSession?> sesionActual() async {
    if (sesionActualThrows != null) throw sesionActualThrows!;
    return sesionActualResult;
  }

  @override
  Future<AuthSession> renovar(String token) async {
    tokensRenovados.add(token);
    if (renovarError != null) throw renovarError!;
    return renovarResult ??
        const AuthSession(
          token: 't-1',
          companyId: 'c-1',
          companyName: 'Empresa 1',
        );
  }

  @override
  Future<void> logout(String? token) async => cierres.add(token);
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

  /// Cada vez que se tocó una entrada que existía, como `leer:clave`. En el
  /// Mac es lo que cuenta: el llavero pregunta por entrada existente, no
  /// por las que no están.
  final List<String> accesos = [];

  /// Todas las llamadas, existiera o no la entrada y fallara o no.
  var llamadas = 0;

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
    llamadas++;
    if (falla) throw Exception('almacén del sistema no disponible');
    if (_values.containsKey(key)) accesos.add('leer:$key');
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
    llamadas++;
    if (falla) throw Exception('almacén del sistema no disponible');
    if (_values.containsKey(key)) accesos.add('escribir:$key');
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
    llamadas++;
    if (falla) throw Exception('almacén del sistema no disponible');
    if (_values.containsKey(key)) accesos.add('borrar:$key');
    _values.remove(key);
  }

  Set<String> get claves => _values.keys.toSet();
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
    expect(storage.claves, {'sesion'});
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

  test('restore renueva el token y guarda el nuevo', () async {
    final storage = _FakeSecureStorage({
      'sesion': jsonEncode({
        'token': 'viejo',
        'companyId': 'c-1',
        'companyName': 'Empresa 1',
      }),
    });
    final api = _FakeAuthApi(
      renovarResult: const AuthSession(
        token: 'nuevo',
        companyId: 'c-1',
        companyName: 'Empresa 1',
      ),
    );
    final notifier = AuthNotifier(api: api, storage: storage);
    await notifier.restoreSession();
    expect(notifier.state.session?.token, 'nuevo');
    expect(jsonDecode((await storage.read(key: 'sesion'))!)['token'], 'nuevo');
    notifier.dispose();
  });

  test('el ciclo horario renueva y guarda', () async {
    final storage = _FakeSecureStorage({
      'sesion': jsonEncode({
        'token': 'viejo',
        'companyId': 'c-1',
        'companyName': 'Empresa 1',
      }),
    });
    final api = _FakeAuthApi(
      renovarResult: const AuthSession(
        token: 'nuevo',
        companyId: 'c-1',
        companyName: 'Empresa 1',
      ),
    );
    final notifier = AuthNotifier(
      api: api,
      storage: storage,
      renovarCada: const Duration(seconds: 1),
    );
    await notifier.restoreSession();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(api.tokensRenovados.length, greaterThanOrEqualTo(2));
    expect(notifier.state.session?.token, 'nuevo');
    notifier.dispose();
  });

  test('401 renueva y deja la sesión cerrada', () async {
    final storage = _FakeSecureStorage({
      'sesion': jsonEncode({
        'token': 'viejo',
        'companyId': 'c-1',
        'companyName': 'Empresa 1',
      }),
    });
    final notifier = AuthNotifier(
      api: _FakeAuthApi(renovarError: const SessionRevokedException()),
      storage: storage,
    );
    await notifier.restoreSession();
    expect(notifier.state.status, AuthStatus.unauthenticated);
    expect(await storage.read(key: 'sesion'), isNull);
    notifier.dispose();
  });

  test('error de red al renovar conserva sesión', () async {
    final storage = _FakeSecureStorage({
      'sesion': jsonEncode({
        'token': 'viejo',
        'companyId': 'c-1',
        'companyName': 'Empresa 1',
      }),
    });
    final notifier = AuthNotifier(
      api: _FakeAuthApi(renovarError: Exception('sin red')),
      storage: storage,
    );
    await notifier.restoreSession();
    expect(notifier.state.session?.token, 'viejo');
    notifier.dispose();
  });

  test(
    'restoreSession con token rechazado por el backend limpia la sesión guardada',
    () async {
      final storage = _FakeSecureStorage({
        'auth_token': 't-1',
        'auth_company_id': 'c-1',
        'auth_company_name': 'Empresa 1',
      });
      final notifier = AuthNotifier(
        api: _FakeAuthApi(renovarError: const SessionRevokedException()),
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
        api: _FakeAuthApi(renovarError: Exception('sin red')),
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

  // En el navegador la sesión vive en la cookie HttpOnly del backend y la
  // clave la recuerda el gestor de contraseñas del navegador. El panel no
  // guarda nada: flutter_secure_storage en web escribe en el
  // almacenamiento de la página, que un script inyectado lee.
  group('en el navegador', () {
    const deCookie = AuthSession(
      token: null,
      companyId: 'c-1',
      companyName: 'Empresa 1',
    );

    test('entrar no guarda nada, ni con «recordar»', () async {
      final storage = _FakeSecureStorage();
      final notifier = AuthNotifier(
        api: _FakeAuthApi(loginResult: deCookie),
        storage: storage,
        web: true,
      );

      expect(await notifier.login('admin', 'clave', recordar: true), isTrue);

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.session?.token, isNull);
      expect(await notifier.credencialesRecordadas(), isNull);
      expect(storage.llamadas, 0);
    });

    test('al abrir, la sesión la dice el servidor por la cookie', () async {
      final storage = _FakeSecureStorage({'sesion': '{"token":"viejo"}'});
      final notifier = AuthNotifier(
        api: _FakeAuthApi(sesionActualResult: deCookie),
        storage: storage,
        web: true,
      );

      await notifier.restoreSession();

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.session?.companyName, 'Empresa 1');
      expect(storage.llamadas, 0);
    });

    test('sin cookie viva, o sin red, se pide la clave', () async {
      for (final api in [
        _FakeAuthApi(),
        _FakeAuthApi(sesionActualThrows: Exception('sin red')),
      ]) {
        final notifier = AuthNotifier(
          api: api,
          storage: _FakeSecureStorage(),
          web: true,
        );

        await notifier.restoreSession();

        expect(notifier.state.status, AuthStatus.unauthenticated);
      }
    });

    test('salir le pide al servidor borrar la cookie', () async {
      final storage = _FakeSecureStorage();
      final api = _FakeAuthApi(loginResult: deCookie);
      final notifier = AuthNotifier(api: api, storage: storage, web: true);
      await notifier.login('admin', 'clave');

      await notifier.logout();

      expect(api.cierres, [null]);
      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(storage.llamadas, 0);
    });
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

    test('en web va sin Authorization: lo lleva la cookie', () async {
      await AuthApi(baseUrl: base()).logout(null);

      expect(pedidos, ['POST /api/fleet/logout null']);
    });

    test('sin servidor no lanza', () async {
      final puerto = servidor.port;
      await servidor.close(force: true);

      await AuthApi(baseUrl: 'http://127.0.0.1:$puerto').logout('t-1');
    });
  });

  // «Recordar contraseña» (pedido del dueño, 2026-09-28): usuario y clave
  // van al almacén cifrado del sistema —el Llavero en macOS, el archivo
  // cifrado con la clave del usuario en Windows—, nunca a un archivo plano.
  // Los valores de aquí son de prueba.
  group('recordar contraseña', () {
    test('con la casilla, guarda usuario y clave y los devuelve', () async {
      final storage = _FakeSecureStorage();
      final notifier = AuthNotifier(
        api: _FakeAuthApi(loginResult: session),
        storage: storage,
      );

      await notifier.login('operador', 'clave-de-prueba', recordar: true);

      final recordadas = await notifier.credencialesRecordadas();
      expect(recordadas?.usuario, 'operador');
      expect(recordadas?.clave, 'clave-de-prueba');
    });

    test('sin la casilla, olvida lo que hubiera', () async {
      final storage = _FakeSecureStorage({
        'recordar_usuario': 'operador',
        'recordar_clave': 'clave-vieja',
      });
      final notifier = AuthNotifier(
        api: _FakeAuthApi(loginResult: session),
        storage: storage,
      );

      await notifier.login('operador', 'clave-de-prueba');

      expect(await notifier.credencialesRecordadas(), isNull);
      expect(await storage.read(key: 'recordar_clave'), isNull);
    });

    test('un ingreso rechazado no toca lo recordado', () async {
      final storage = _FakeSecureStorage({
        'recordar_usuario': 'operador',
        'recordar_clave': 'clave-buena',
      });
      final notifier = AuthNotifier(
        api: _FakeAuthApi(
          loginError: const AuthApiException(
            'Usuario o contraseña incorrectos.',
          ),
        ),
        storage: storage,
      );

      await notifier.login('operador', 'clave-mala');

      expect((await notifier.credencialesRecordadas())?.clave, 'clave-buena');
    });

    test('salir no olvida la contraseña: para eso se recordó', () async {
      final storage = _FakeSecureStorage();
      final notifier = AuthNotifier(
        api: _FakeAuthApi(loginResult: session),
        storage: storage,
      );
      await notifier.login('operador', 'clave-de-prueba', recordar: true);

      await notifier.logout();

      expect(await storage.read(key: 'auth_token'), isNull);
      expect((await notifier.credencialesRecordadas())?.usuario, 'operador');
    });

    test(
      'si el almacén se niega, no hay nada recordado y se entra igual',
      () async {
        final storage = _FakeSecureStorage()..falla = true;
        final notifier = AuthNotifier(
          api: _FakeAuthApi(loginResult: session),
          storage: storage,
        );

        expect(await notifier.credencialesRecordadas(), isNull);
        expect(
          await notifier.login('operador', 'clave-de-prueba', recordar: true),
          isTrue,
        );
      },
    );
  });

  // El dueño, 2026-09-30: «le di a guardar contraseña y cada vez que cierro
  // sesión me toca poner la contraseña [del llavero] como 3 veces». El
  // llavero del Mac pregunta por cada entrada, y eran cinco: token, id y
  // nombre de la empresa, usuario y clave. Ahora son dos —la sesión y lo
  // recordado— y lo recordado no se reescribe si no cambió.
  group('el llavero se toca lo menos posible', () {
    test('la sesión y lo recordado van en una entrada cada uno', () async {
      final storage = _FakeSecureStorage();
      final notifier = AuthNotifier(
        api: _FakeAuthApi(loginResult: session),
        storage: storage,
      );

      await notifier.login('operador', 'clave-de-prueba', recordar: true);

      expect(storage.claves, {'sesion', 'recordar'});
    });

    test('salir y volver a entrar con la clave recordada la lee una vez y '
        'no la reescribe', () async {
      final storage = _FakeSecureStorage();
      final notifier = AuthNotifier(
        api: _FakeAuthApi(loginResult: session),
        storage: storage,
      );
      await notifier.login('operador', 'clave-de-prueba', recordar: true);
      await notifier.logout();
      storage.accesos.clear();

      // Lo que hace la pantalla de ingreso: rellena y manda.
      final recordadas = await notifier.credencialesRecordadas();
      await notifier.login(
        recordadas!.usuario,
        recordadas.clave,
        recordar: true,
      );

      expect(storage.accesos, ['leer:recordar']);
    });

    test('si la clave cambió, sí la reescribe', () async {
      final storage = _FakeSecureStorage();
      final notifier = AuthNotifier(
        api: _FakeAuthApi(loginResult: session),
        storage: storage,
      );
      await notifier.login('operador', 'clave-vieja', recordar: true);
      await notifier.logout();
      await notifier.credencialesRecordadas();

      await notifier.login('operador', 'clave-nueva', recordar: true);

      expect((await notifier.credencialesRecordadas())?.clave, 'clave-nueva');
    });

    test('lo guardado en las cinco entradas de antes se pasa a las dos y '
        'las viejas se borran', () async {
      final storage = _FakeSecureStorage({
        'auth_token': 't-1',
        'auth_company_id': 'c-1',
        'auth_company_name': 'Empresa 1',
        'recordar_usuario': 'operador',
        'recordar_clave': 'clave-de-prueba',
      });
      final notifier = AuthNotifier(
        api: _FakeAuthApi(validateResult: true),
        storage: storage,
      );

      await notifier.restoreSession();
      final recordadas = await notifier.credencialesRecordadas();

      expect(notifier.state.session?.companyName, 'Empresa 1');
      expect(recordadas?.clave, 'clave-de-prueba');
      expect(storage.claves, {'sesion', 'recordar'});
    });
  });

  // En el Mac la app va firmada «ad hoc» (sin equipo de Apple): el llavero
  // de protección de datos le responde -34018 (falta el derecho
  // keychain-access-groups) y nada se guardaba —ni la sesión ni la clave
  // recordada—. El llavero clásico del inicio de sesión sí la deja.
  test('en macOS guarda en el llavero clásico, no en el de protección', () {
    // Lo que viaja al plugin nativo.
    expect(
      AuthNotifier.almacenDelSistema.mOptions
          .toMap()['usesDataProtectionKeychain'],
      'false',
    );
  });
}
