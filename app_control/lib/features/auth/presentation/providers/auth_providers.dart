import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Solo el provider de la URL: el resto del paquete choca con el tema local.
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show backendUrlProvider;

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
  AuthNotifier({required this._api, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        super(const AuthState());

  static const _kToken = 'auth_token';
  static const _kCompanyId = 'auth_company_id';
  static const _kCompanyName = 'auth_company_name';

  final AuthApi _api;
  final FlutterSecureStorage _storage;

  Future<void> restoreSession() async {
    String? token;
    String? companyId;
    String? companyName;
    try {
      token = await _storage.read(key: _kToken);
      companyId = await _storage.read(key: _kCompanyId);
      companyName = await _storage.read(key: _kCompanyName);
    } catch (e) {
      // Si el almacén del sistema no se deja leer, no hay sesión que
      // restaurar: se pide la clave y ya. Sin este catch la excepción subía
      // sin dueño y la ventana se quedaba en el estado inicial para siempre.
      debugPrint('No se pudo leer la sesión guardada: $e');
    }
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
    try {
      await _storage.delete(key: _kToken);
      await _storage.delete(key: _kCompanyId);
      await _storage.delete(key: _kCompanyName);
    } catch (e) {
      debugPrint('No se pudo borrar la sesión guardada: $e');
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(loading: true, error: null);

    final AuthSession session;
    try {
      session = await _api.login(username, password);
    } on AuthApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (e) {
      debugPrint('Fallo inesperado al pedir el ingreso: $e');
      state = state.copyWith(
        loading: false,
        error: 'No se pudo conectar con el servidor.',
      );
      return false;
    }

    // Guardar la sesión es una comodidad para el próximo arranque, no un
    // requisito para entrar. El almacén cifrado lo pone el sistema
    // (Credenciales de Windows, Llavero en macOS) y puede negarse por
    // permisos o por política de la máquina.
    //
    // Antes estas tres escrituras estaban dentro del mismo try que la
    // llamada de red, y su `catch` decía "No se pudo conectar con el
    // servidor": el panel rechazaba el ingreso con un mensaje que culpaba a
    // la red aunque el servidor hubiera contestado 200. Ahora, si el almacén
    // falla, se entra igual y lo único que se pierde es no tener que volver
    // a escribir la clave en el próximo arranque.
    try {
      await _storage.write(key: _kToken, value: session.token);
      await _storage.write(key: _kCompanyId, value: session.companyId);
      await _storage.write(key: _kCompanyName, value: session.companyName);
    } catch (e) {
      debugPrint('Se entró, pero no se pudo guardar la sesión: $e');
    }

    state = AuthState(status: AuthStatus.authenticated, session: session);
    return true;
  }

  Future<void> logout() async {
    await _clearStored();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// El login contra el backend que resolvió el arranque (`main.dart`
/// sobrescribe `backendUrlProvider` con lo que eligió `BackendResolver`).
final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(baseUrl: ref.watch(backendUrlProvider)),
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(api: ref.watch(authApiProvider));
});
