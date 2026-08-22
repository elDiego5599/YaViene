import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ya_viene_control/features/auth/data/auth_api.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({this.loginResult, this.loginError, this.validateResult, this.validateThrows});

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

void main() {
  const session = AuthSession(token: 't-1', companyId: 'c-1', companyName: 'Empresa 1');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('login exitoso deja el estado autenticado y guarda la sesión', () async {
    final notifier = AuthNotifier(api: _FakeAuthApi(loginResult: session));

    final ok = await notifier.login('admin', 'admin123');

    expect(ok, true);
    expect(notifier.state.status, AuthStatus.authenticated);
    expect(notifier.state.session?.token, 't-1');
    expect(notifier.state.error, null);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), 't-1');
  });

  test('login con credenciales incorrectas deja el mensaje de error, sin sesión', () async {
    final notifier = AuthNotifier(
      api: _FakeAuthApi(loginError: const AuthApiException('Usuario o contraseña incorrectos.')),
    );

    final ok = await notifier.login('admin', 'mala-clave');

    expect(ok, false);
    expect(notifier.state.status, AuthStatus.unknown);
    expect(notifier.state.error, 'Usuario o contraseña incorrectos.');
    expect(notifier.state.loading, false);
  });

  test('restoreSession con token guardado y válido entra autenticado', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 't-1',
      'auth_company_id': 'c-1',
      'auth_company_name': 'Empresa 1',
    });
    final notifier = AuthNotifier(api: _FakeAuthApi(validateResult: true));

    await notifier.restoreSession();

    expect(notifier.state.status, AuthStatus.authenticated);
    expect(notifier.state.session?.companyId, 'c-1');
  });

  test('restoreSession con token rechazado por el backend limpia la sesión guardada', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 't-1',
      'auth_company_id': 'c-1',
      'auth_company_name': 'Empresa 1',
    });
    final notifier = AuthNotifier(api: _FakeAuthApi(validateResult: false));

    await notifier.restoreSession();

    expect(notifier.state.status, AuthStatus.unauthenticated);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), null);
  });

  test('restoreSession sin red mantiene la sesión guardada (el dashboard reintentará)', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 't-1',
      'auth_company_id': 'c-1',
      'auth_company_name': 'Empresa 1',
    });
    final notifier = AuthNotifier(api: _FakeAuthApi(validateThrows: Exception('sin red')));

    await notifier.restoreSession();

    expect(notifier.state.status, AuthStatus.authenticated);
    expect(notifier.state.session?.token, 't-1');
  });

  test('restoreSession sin nada guardado deja no autenticado', () async {
    final notifier = AuthNotifier(api: _FakeAuthApi());

    await notifier.restoreSession();

    expect(notifier.state.status, AuthStatus.unauthenticated);
    expect(notifier.state.session, null);
  });
}
