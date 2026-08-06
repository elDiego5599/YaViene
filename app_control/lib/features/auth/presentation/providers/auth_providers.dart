import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  AuthNotifier() : super(const AuthState());

  static const _kToken = 'auth_token';
  static const _kCompanyId = 'auth_company_id';
  static const _kCompanyName = 'auth_company_name';

  final _api = AuthApi();

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final companyId = prefs.getString(_kCompanyId);
    final companyName = prefs.getString(_kCompanyName);
    if (token != null && companyId != null && companyName != null) {
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

  Future<bool> login(String username, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final session = await _api.login(username, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, session.token);
      await prefs.setString(_kCompanyId, session.companyId);
      await prefs.setString(_kCompanyName, session.companyName);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kCompanyId);
    await prefs.remove(_kCompanyName);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
