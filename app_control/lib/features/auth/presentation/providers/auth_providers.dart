import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/auth_api.dart';
import '../../domain/auth_session.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.error,
    this.loading = false,
  });

  final AuthStatus status;
  final AuthSession? session;
  final String? error;
  final bool loading;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? error,
    bool? loading,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      error: error,
      loading: loading ?? this.loading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({AuthApi? api, FlutterSecureStorage? storage})
      : _api = api ?? AuthApi(),
        _storage = storage ?? const FlutterSecureStorage(),
        super(const AuthState());

  static const _kToken = 'auth_token';
  static const _kCompanyId = 'auth_company_id';
  static const _kCompanyName = 'auth_company_name';

  final AuthApi _api;
  final FlutterSecureStorage _storage;

  Future<void> restoreSession() async {
    final token = await _storage.read(key: _kToken);
    final companyId = await _storage.read(key: _kCompanyId);
    final companyName = await _storage.read(key: _kCompanyName);
    if (token != null && companyId != null && companyName != null) {
      // Validamos el token guardado: si el backend lo rechaza (p.ej. secretos
      // rotados o token expirado), no entramos con una sesión muerta.
      try {
        final valid = await _api.validateSession(token);
        if (!valid) {
          await _clearStored();
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }
      } catch (_) {
        // Sin red: mantenemos la sesión; el dashboard reintentará.
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        session: AuthSession(
          token: token,
          companyId: companyId,
          companyName: companyName,
        ),
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _clearStored() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kCompanyId);
    await _storage.delete(key: _kCompanyName);
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final session = await _api.login(username, password);
      await _storage.write(key: _kToken, value: session.token);
      await _storage.write(key: _kCompanyId, value: session.companyId);
      await _storage.write(key: _kCompanyName, value: session.companyName);
      state = AuthState(status: AuthStatus.authenticated, session: session);
      return true;
    } on AuthApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: 'No se pudo conectar con el servidor.');
      return false;
    }
  }

  Future<void> logout() async {
    await _clearStored();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
