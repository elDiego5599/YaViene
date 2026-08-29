import 'dart:async';

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
  final String? uid;
  final String? email;
  final String? name;
  final bool isNewUser;
  final String? errorMessage;

  /// Código de error de Firebase (p. ej. 'email-already-in-use') para que la
  /// pantalla decida el siguiente paso sin depender del texto.
  final String? errorCode;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.uid,
    this.email,
    this.name,
    this.isNewUser = false,
    this.errorMessage,
    this.errorCode,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? uid,
    String? email,
    String? name,
    bool? isNewUser,
    Object? errorMessage = _notProvided,
    Object? errorCode = _notProvided,
  }) {
    return AuthState(
      status: status ?? this.status,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      isNewUser: isNewUser ?? this.isNewUser,
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

  final Completer<void> _sessionResolved = Completer<void>();

  /// Se completa en cuanto Firebase emite su primer estado (sesión restaurada
  /// desde el dispositivo, o confirmado que no hay sesión). El splash espera
  /// esto antes de decidir a qué pantalla ir.
  Future<void> get sessionResolved => _sessionResolved.future;

  AuthState get state => _state;

  StreamSubscription<User?>? _authSub;

  AuthNotifier() {
    _authSub = _auth.authStateChanges().listen((user) {
      if (!_sessionResolved.isCompleted) _sessionResolved.complete();
      if (user != null && _state.status != AuthStatus.verified) {
        _state = AuthState(
          status: AuthStatus.verified,
          uid: user.uid,
          email: user.email,
          name: user.displayName,
          isNewUser: false,
        );
        notifyListeners();
      } else if (user == null && _state.status != AuthStatus.unauthenticated) {
        _state = const AuthState();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  static Future<void> _ensureGoogleInitialized() async {
    if (!_googleInitialized) {
      await _google.initialize();
      _googleInitialized = true;
    }
  }

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

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
      if (methods.isNotEmpty) {
        return _settle(false); // solo Google: sin contraseña
      }
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
        errorMessage:
            'No se pudo conectar: revisa tu internet e intenta de nuevo',
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
        uid: result.user?.uid,
        email: result.user?.email,
        name: name.trim(),
        isNewUser: true,
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
        errorMessage:
            'No se pudo conectar: revisa tu internet e intenta de nuevo',
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
        uid: result.user?.uid,
        email: result.user?.email,
        name: result.user?.displayName,
        isNewUser: false,
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
        errorMessage:
            'No se pudo conectar: revisa tu internet e intenta de nuevo',
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
      final idToken = googleUser.authentication.idToken;
      // Sin idToken (plataforma/dispositivo sin Play Services o configuración
      // incompleta) el credential de Firebase no se puede construir.
      if (idToken == null) {
        _state = const AuthState(
            status: AuthStatus.error,
            errorMessage: 'No se pudo obtener la sesión de Google');
        notifyListeners();
        return false;
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      _state = AuthState(
        status: AuthStatus.verified,
        uid: result.user?.uid,
        email: result.user?.email,
        name: result.user?.displayName,
        isNewUser: result.additionalUserInfo?.isNewUser ?? false,
      );
      notifyListeners();
      return true;
    } on GoogleSignInException catch (e) {
      // Cerrar el selector de cuentas no es un error y se vuelve al estado
      // inicial sin decir nada. Todo lo demás SÍ lo es, y antes caía en esta
      // misma rama: la app se quedaba muda y el botón parecía no hacer nada.
      // El fallo que escondía era clientConfigurationError — en Android
      // significa que el SHA-1 del certificado que firma la APK no está
      // registrado en el proyecto de Firebase.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _state = const AuthState();
        notifyListeners();
        return false;
      }
      debugPrint('Google sign-in falló (${e.code.name}): ${e.description}');
      _state = AuthState(
        status: AuthStatus.error,
        errorMessage: _googleSignInError(e.code),
        errorCode: e.code.name,
      );
      notifyListeners();
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
      _state = const AuthState(
        status: AuthStatus.error,
        errorMessage:
            'No se pudo conectar con Google: revisa tu internet e intenta de nuevo',
      );
      notifyListeners();
      return false;
    }
  }

  /// Envía el correo de restablecimiento de contraseña. Devuelve `null` si se
  /// envió, o un mensaje de error si falló. No toca el estado general de
  /// auth: es una acción aparte, no un intento de inicio de sesión.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    } catch (e) {
      return 'No se pudo conectar: revisa tu internet e intenta de nuevo';
    }
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (e, st) {
      debugPrint('signOut Google failed: $e\n$st');
    }
    await _auth.signOut();
    _state = const AuthState();
    notifyListeners();
  }

  /// Texto para los fallos de Google que no son una cancelación. Los de
  /// configuración se cuentan como "no disponible" y no como "error de red":
  /// no dependen del usuario y reintentar no cambia nada, así que lo útil es
  /// mandarlo al ingreso por correo en vez de dejarlo insistiendo.
  String _googleSignInError(GoogleSignInExceptionCode code) {
    switch (code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'El ingreso con Google no está disponible en esta versión de '
            'la app. Entra con tu correo y contraseña.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'No se pudo abrir el selector de cuentas de Google. '
            'Intenta de nuevo.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Esa cuenta de Google no coincide con la sesión actual. '
            'Cierra sesión e intenta de nuevo.';
      case GoogleSignInExceptionCode.canceled:
      case GoogleSignInExceptionCode.interrupted:
      case GoogleSignInExceptionCode.unknownError:
        return 'No se pudo entrar con Google. Intenta de nuevo o usa tu '
            'correo y contraseña.';
    }
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
      case 'invalid-login-credentials':
        return 'Correo o contraseña incorrectos';
      case 'user-not-found':
        return 'No existe una cuenta con ese correo';
      case 'account-exists-with-different-credential':
        return 'Ese correo ya tiene una cuenta creada con otro método '
            '(p. ej. Google); entra con ese método';
      case 'operation-not-allowed':
        return 'Este método de acceso no está habilitado todavía';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada';
      case 'network-request-failed':
        return 'Sin conexión a internet';
      case 'too-many-requests':
        return 'Demasiados intentos, espera un momento e intenta de nuevo';
      default:
        return e.message ?? 'Error de autenticación';
    }
  }
}
