import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo demo: el inicio de sesión es por correo sin verificación real.
/// La estructura queda lista para conectar un proveedor de verificación
/// (código por correo o magic link) sin tocar las pantallas.
enum AuthStatus { unauthenticated, loading, verified, error }

final authProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.email,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    Object? errorMessage = _notProvided,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  /// Sentinel para distinguir "no tocar errorMessage" de "limpiarlo".
  static const Object _notProvided = Object();
}

class AuthNotifier extends ChangeNotifier {
  AuthState _state = const AuthState();

  AuthState get state => _state;

  static final RegExp _emailPattern =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool isEmailValid(String email) => _emailPattern.hasMatch(email.trim());

  Future<bool> signInWithEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!isEmailValid(normalized)) {
      _state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Ingresa un correo electrónico válido',
      );
      notifyListeners();
      return false;
    }

    _state = AuthState(status: AuthStatus.loading, email: normalized);
    notifyListeners();

    // Demo: la sesión se crea de inmediato. Cuando exista un proveedor de
    // verificación por correo, aquí se envía el código y se pasa a un
    // estado intermedio antes de quedar verified.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _state = AuthState(status: AuthStatus.verified, email: normalized);
    notifyListeners();
    return true;
  }

  Future<void> signOut() async {
    _state = const AuthState();
    notifyListeners();
  }
}
