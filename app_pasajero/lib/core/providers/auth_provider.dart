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
  final String? name;
  final String? errorMessage;

  /// Código de error de Firebase (p. ej. 'email-already-in-use') para que la
  /// pantalla decida el siguiente paso sin depender del texto.
  final String? errorCode;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.email,
    this.name,
    this.errorMessage,
    this.errorCode,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? name,
    Object? errorMessage = _notProvided,
    Object? errorCode = _notProvided,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      name: name ?? this.name,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
      errorCode: identical(errorCode, _notProvided)
          ? this.errorCode
          : errorCode as String?,
    );
  }

  /// Sentinel para distinguir "no tocar" de "limpiar".
  static const Object _notProvided = Object();
}

/// Autenticación con Firebase Auth (Email/Password), con el flujo tipo Zara
/// en las pantallas: primero el correo; si la cuenta existe se pide la
/// contraseña y si no se crea el perfil.
class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _google = GoogleSignIn.instance;
  static bool _googleInitialized = false;
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

  static Future<void> _ensureGoogleInitialized() async {
    if (!_googleInitialized) {
      await _google.initialize();
      _googleInitialized = true;
    }
  }

  static final RegExp _emailPattern =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool isEmailValid(String email) => _emailPattern.hasMatch(email.trim());

  /// Verifica si el correo ya tiene cuenta. Devuelve null en error de red.
  ///
  /// Firebase deprecó la consulta de métodos (protección anti-enumeración) y
  /// hoy puede devolver "no existe" para cuentas que SÍ existen: por eso, si
  /// la consulta no da una respuesta positiva (o da vacío), se hace una
  /// segunda prueba intentando entrar con una contraseña falsa:
  ///   - 'wrong-password'  → la cuenta existe
  ///   - 'invalid-credential' → puede existir (respuesta protegida): se trata
  ///     como existente para nunca mandarte a registrarte dos veces
  ///   - 'user-not-found' / 'invalid-login-credentials' → no existe
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
      // ignore: deprecated_member_use
      final methods = await _auth.fetchSignInMethodsForEmail(normalized);
      if (methods.contains('password')) return _settle(true);
      if (methods.isNotEmpty) return _settle(false); // solo Google: sin contraseña
      return _settle(await _probeExistence(normalized));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return _settle(false);
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyAuthError(e),
        errorCode: e.code,
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

  bool? _settle(bool exists) {
    _state = _state.copyWith(status: AuthStatus.unauthenticated);
    notifyListeners();
    return exists;
  }

  Future<bool> _probeExistence(String email) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: 'probe-invalida-xyz',
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          return true;
        case 'invalid-credential':
          // Protección anti-enumeración activa: no se puede distinguir.
          // Tratarlo como existente evita el "me mandó a registrarme otra
          // vez" aunque la cuenta sí exista.
          return true;
        case 'user-not-found':
        case 'invalid-login-credentials':
          return false;
        default:
          return true;
      }
    }
    return true;
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
        errorCode: e.code,
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
        errorCode: e.code,
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
        name: result.user?.displayName,
      );
      notifyListeners();
      return true;
    } on GoogleSignInException catch (e) {
      // Canceló el selector de cuentas: no es un error.
      _state = const AuthState();
      notifyListeners();
      debugPrint('Google sign-in cancelado: $e');
      return false;
    } on FirebaseAuthException catch (e) {
      _state = AuthState(
        status: AuthStatus.error,
        errorMessage: _friendlyAuthError(e),
        errorCode: e.code,
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
