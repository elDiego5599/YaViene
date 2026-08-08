import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthStatus { unauthenticated, loading, codeSent, verified, error }

class AuthState {
  final AuthStatus status;
  final String? verificationId;
  final String? phoneNumber;
  final String? errorMessage;
  final User? user;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.verificationId,
    this.phoneNumber,
    this.errorMessage,
    this.user,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? verificationId,
    String? phoneNumber,
    Object? errorMessage = _notProvided,
    User? user,
  }) {
    return AuthState(
      status: status ?? this.status,
      verificationId: verificationId ?? this.verificationId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
      user: user ?? this.user,
    );
  }

  /// Sentinel para distinguir "no tocar errorMessage" de "limpiarlo".
  static const Object _notProvided = Object();
}

class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  AuthState _state = const AuthState();

  AuthState get state => _state;

  AuthNotifier() {
    _auth.authStateChanges().listen((user) {
      if (user != null && _state.status != AuthStatus.verified) {
        _state = _state.copyWith(status: AuthStatus.verified, user: user);
        notifyListeners();
      }
    });
  }

  Future<void> verifyPhone(String phoneNumber) async {
    final fullNumber = phoneNumber.startsWith('+') ? phoneNumber : '+57$phoneNumber';
    _state = _state.copyWith(
      status: AuthStatus.loading,
      phoneNumber: fullNumber,
      errorMessage: null,
    );
    notifyListeners();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: fullNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (e) {
          _state = _state.copyWith(
            status: AuthStatus.error,
            errorMessage: e.message ?? 'Error de verificación',
          );
          notifyListeners();
        },
        codeSent: (verificationId, resendToken) {
          _state = _state.copyWith(
            status: AuthStatus.codeSent,
            verificationId: verificationId,
          );
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (_state.status == AuthStatus.loading) {
            _state = _state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'Tiempo de espera agotado',
            );
            notifyListeners();
          }
        },
      );
    } catch (e) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      notifyListeners();
    }
  }

  Future<bool> verifyCode(String smsCode) async {
    if (_state.verificationId == null) return false;
    _state = _state.copyWith(status: AuthStatus.loading);
    notifyListeners();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _state.verificationId!,
        smsCode: smsCode,
      );
      final result = await _auth.signInWithCredential(credential);
      _state = _state.copyWith(
        status: AuthStatus.verified,
        user: result.user,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Código incorrecto, inténtalo de nuevo',
      );
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _state = const AuthState();
    notifyListeners();
  }
}
