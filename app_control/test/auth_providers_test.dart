import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ya_viene_control/features/auth/data/auth_api.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({this.loginResult, this.loginError, this.validateResult, this.validateThrows})
      : super(baseUrl: 'http://localhost:3000');

  final AuthSession? loginResult;
  final AuthApiException? loginError;
  final bool? validateResult;
  final Object? validateThrows;

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
}

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? initialValues])
      : _values = {...?initialValues};

  final Map<String, String> _values;

  /// Cuando el almacén del sistema se niega. En Windows es el almacén de
  /// Credenciales y en macOS el Llavero: los dos pueden fallar por permisos o
  /// por política de la máquina, y hasta ahora ninguna prueba lo cubría porque
  /// este doble siempre respondía que sí.
  bool falla = false;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (falla) throw Exception('almacén del sistema no disponible');
    return _values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
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
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (falla) throw Exception('almacén del sistema no disponible');
    _values.remove(key);
  }
}

void main() {
  const session = AuthSession(token: 't-1', companyId: 'c-1', companyName: 'Empresa 1');

  test('login exitoso deja el estado autenticado y guarda la sesión', () async {
    final storage = _FakeSecureStorage();
    final notifier = AuthNotifier(api: _FakeAuthApi(loginResult: session), storage: storage);

    final ok = await notifier.login('admin', 'admin123');

    expect(ok, true);
    expect(notifier.state.status, AuthStatus.authenticated);
    expect(notifier.state.session?.token, 't-1');
    expect(notifier.state.error, null);
    expect(await storage.read(key: 'auth_token'), 't-1');
  });

  test('login con credenciales incorrectas deja el mensaje de error, sin sesión', () async {
    final notifier = AuthNotifier(
      api: _FakeAuthApi(loginError: const AuthApiException('Usuario o contraseña incorrectos.')),
      storage: _FakeSecureStorage(),
    );

    final ok = await notifier.login('admin', 'mala-clave');

    expect(ok, false);
    expect(notifier.state.status, AuthStatus.unknown);
    expect(notifier.state.error, 'Usuario o contraseña incorrectos.');
    expect(notifier.state.loading, false);
  });

  test('restoreSession con token guardado y válido entra autenticado', () async {
    final storage = _FakeSecureStorage({
      'auth_token': 't-1',
      'auth_company_id': 'c-1',
      'auth_company_name': 'Empresa 1',
    });
    final notifier = AuthNotifier(api: _FakeAuthApi(validateResult: true), storage: storage);

    await notifier.restoreSession();

    expect(notifier.state.status, AuthStatus.authenticated);
    expect(notifier.state.session?.companyId, 'c-1');
  });

  test('restoreSession con token rechazado por el backend limpia la sesión guardada', () async {
    final storage = _FakeSecureStorage({
      'auth_token': 't-1',
      'auth_company_id': 'c-1',
      'auth_company_name': 'Empresa 1',
    });
    final notifier = AuthNotifier(api: _FakeAuthApi(validateResult: false), storage: storage);

    await notifier.restoreSession();

    expect(notifier.state.status, AuthStatus.unauthenticated);
    expect(await storage.read(key: 'auth_token'), null);
  });

  test('restoreSession sin red mantiene la sesión guardada (el dashboard reintentará)', () async {
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
  });

  test('restoreSession sin nada guardado deja no autenticado', () async {
    final notifier = AuthNotifier(api: _FakeAuthApi(), storage: _FakeSecureStorage());

    await notifier.restoreSession();

    expect(notifier.state.status, AuthStatus.unauthenticated);
    expect(notifier.state.session, null);
  });

  // El fallo que llegó a manos del usuario: el servidor contestaba 200 y el
  // panel lo rechazaba con "No se pudo conectar con el servidor", porque las
  // escrituras al almacén del sistema iban dentro del mismo try que la red.
  test('si el almacén del sistema falla, se entra igual y sin error', () async {
    final storage = _FakeSecureStorage()..falla = true;
    final notifier = AuthNotifier(api: _FakeAuthApi(loginResult: session), storage: storage);

    final ok = await notifier.login('admin', 'clave-buena');

    expect(ok, true);
    expect(notifier.state.status, AuthStatus.authenticated);
    expect(notifier.state.session?.token, 't-1');
    expect(notifier.state.error, null);
  });

  test('si el almacén del sistema falla, restoreSession deja no autenticado', () async {
    final storage = _FakeSecureStorage({'auth_token': 't-1'})..falla = true;
    final notifier = AuthNotifier(api: _FakeAuthApi(), storage: storage);

    await notifier.restoreSession();

    expect(notifier.state.status, AuthStatus.unauthenticated);
    expect(notifier.state.session, null);
  });

  test('logout no se atasca si el almacén del sistema falla', () async {
    final storage = _FakeSecureStorage({'auth_token': 't-1'})..falla = true;
    final notifier = AuthNotifier(api: _FakeAuthApi(), storage: storage);

    await notifier.logout();

    expect(notifier.state.status, AuthStatus.unauthenticated);
  });
}
