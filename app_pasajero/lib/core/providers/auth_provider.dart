import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { unauthenticated, loading, verified, error }

final authProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? name;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.email,
    this.name,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? name,
    Object? errorMessage = _notProvided,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      name: name ?? this.name,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  /// Sentinel para distinguir "no tocar errorMessage" de "limpiarlo".
  static const Object _notProvided = Object();
}

/// Autenticación con Firebase Auth (Email/Password), con el flujo tipo Zara
/// en las pantallas: primero el correo; si la cuenta existe se pide la
/// contraseña y si no se crea el perfil.
class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  AuthState _state = const AuthState();

  AuthState get state => _state;

  AuthNotifier() {
    _auth.authStateChanges().listen((user) {
      if (user != null && _state.status != AuthStatus.verified) {
        _state = AuthState(
          status: AuthStatus.verified,
          email: user.email,
          name: user.displayName,
        );
        notifyListeners();
      } else if (user == null && _state.status != AuthStatus.unauthenticated) {
        _state = const AuthState();
        notifyListeners();
      }
    });
  }

  static final RegExp _emailPattern =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool isEmailValid(String email) => _emailPattern.hasMatch(email.trim());

  /// Verifica si el correo ya tiene cuenta. Devuelve null en error de red.
  Future<bool?> checkEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!isEmailValid(normalized)) return null;

    _state = _state.copyWith(
      status: AuthStatus.loading,
      email: normalized,
      errorMessage: null,
    );
    notifyListeners();

    try {
      // Deprecado por Google (protección de enumeración de emails), pero
      // sigue funcionando en proyectos sin esa protección habilitada. Si
      // algún día lo bloquean, el flujo pasa a "intenta entrar; si falla
      // por credenciales desconocidas, ofrece crear la cuenta".
      // ignore: deprecated_member_use
      final methods = await _auth.fetchSignInMethodsForEmail(normalized);
      final exists = methods.contains('password');
      _state = _state.copyWith(status: AuthStatus.unauthenticated);
      notifyListeners();
      return exists;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _state = _state.copyWith(status: AuthStatus.unauthenticated);
        notifyListeners();
        return false;
      }
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyAuthError(e),
      );
      notifyListeners();
      return null;
    } catch (e) {
      _state = AuthState(
        status: AuthStatus.error,
        email: normalized,
        errorMessage: 'No se pudo conectar: $e',
      );
      notifyListeners();
      return null;
    }
  }

  /// Crea la cuenta (el correo no existía según [checkEmail]).
  Future<bool> register({
    required String email,
    required String name,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    _state = _state.copyWith(
      status: AuthStatus.loading,
      email: normalized,
      errorMessage: null,
    );
    notifyListeners();

    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: normalized,
        password: password,
      );
      await result.user?.updateProfile(displayName: name.trim());
      _state = AuthState(
        status: AuthStatus.verified,
        email: result.user?.email,
        name: name.trim(),
      );
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _state = AuthState(
        status: AuthStatus.error,
        email: normalized,
        errorMessage: _friendlyAuthError(e),
      );
      notifyListeners();
      return false;
    } catch (e) {
      _state = AuthState(
        status: AuthStatus.error,
        email: normalized,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    final normalized = email.trim().toLowerCase();
    _state = _state.copyWith(
      status: AuthStatus.loading,
      email: normalized,
      errorMessage: null,
    );
    notifyListeners();

    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: normalized,
        password: password,
      );
      _state = AuthState(
        status: AuthStatus.verified,
        email: result.user?.email,
        name: result.user?.displayName,
      );
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _state = AuthState(
        status: AuthStatus.error,
        email: normalized,
        errorMessage: _friendlyAuthError(e),
      );
      notifyListeners();
      return false;
    } catch (e) {
      _state = AuthState(
        status: AuthStatus.error,
        email: normalized,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _state = const AuthState();
    notifyListeners();
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'Ese correo ya tiene cuenta: inicia sesión con tu contraseña';
      case 'weak-password':
        return 'La contraseña es muy corta (mínimo 6 caracteres)';
      case 'invalid-email':
        return 'Correo electrónico inválido';
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos';
      case 'network-request-failed':
        return 'Sin conexión a internet';
      case 'too-many-requests':
        return 'Demasiados intentos, espera un momento';
      default:
        return e.message ?? 'Error de autenticación';
    }
  }
}
