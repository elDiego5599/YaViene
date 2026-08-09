import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

/// Autenticación real con Firebase: correo + contraseña obligatoria y
/// "Iniciar con Google". Si el correo no tiene cuenta, se crea al momento
/// (auto-registro con la contraseña que el usuario escribe).
class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _google = GoogleSignIn.instance;
  static bool _googleInitialized = false;
  AuthState _state = const AuthState();

  AuthState get state => _state;

  AuthNotifier() {
    _auth.authStateChanges().listen((user) {
      if (user != null && _state.status != AuthStatus.verified) {
        _state = _state.copyWith(
          status: AuthStatus.verified,
          email: user.email,
        );
        notifyListeners();
      } else if (user == null) {
        _state = const AuthState();
        notifyListeners();
      }
    });
  }

  static Future<void> _ensureGoogleInitialized() async {
    if (!_googleInitialized) {
      await _google.initialize();
      _googleInitialized = true;
    }
  }

  static final RegExp _emailPattern =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool isEmailValid(String email) => _emailPattern.hasMatch(email.trim());

  Future<bool> signInWithEmailAndPassword(
      String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (!isEmailValid(normalized) || password.length < 6) {
      _state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Ingresa un correo válido y una contraseña de al menos 6 caracteres',
      );
      notifyListeners();
      return false;
    }

    _state = AuthState(status: AuthStatus.loading, email: normalized);
    notifyListeners();

    try {
      UserCredential result;
      try {
        result = await _auth.signInWithEmailAndPassword(
          email: normalized,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        // Sin cuenta: se crea al momento con la contraseña escrita.
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          result = await _auth.createUserWithEmailAndPassword(
            email: normalized,
            password: password,
          );
        } else {
          rethrow;
        }
      }
      _state = AuthState(
        status: AuthStatus.verified,
        email: result.user?.email ?? normalized,
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

  Future<bool> signInWithGoogle() async {
    _state = const AuthState(status: AuthStatus.loading);
    notifyListeners();
    try {
      await _ensureGoogleInitialized();
      final googleUser = await _google.authenticate(scopeHint: ['email']);
      final credential = GoogleAuthProvider.credential(
        idToken: googleUser.authentication.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      _state = AuthState(
        status: AuthStatus.verified,
        email: result.user?.email,
      );
      notifyListeners();
      return true;
    } on GoogleSignInException catch (e) {
      // Canceló el selector de cuentas o no pudo abrirlo: no es un error.
      _state = const AuthState();
      notifyListeners();
      debugPrint('Google sign-in cancelado: $e');
      return false;
    } on FirebaseAuthException catch (e) {
      _state = AuthState(
        status: AuthStatus.error,
        errorMessage: _friendlyAuthError(e),
      );
      notifyListeners();
      return false;
    } catch (e) {
      _state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
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
      case 'network-request-failed':
        return 'Sin conexión a internet';
      case 'too-many-requests':
        return 'Demasiados intentos, espera un momento';
      default:
        return e.message ?? 'Error de autenticación';
    }
  }
}
