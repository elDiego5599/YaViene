import 'dart:async';
import 'dart:convert';

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
  /// [web]: el panel corre en el navegador. Ahí no se guarda nada —ni la
  /// sesión ni la clave— y el almacén ni se toca: flutter_secure_storage en
  /// web escribe en el almacenamiento de la página, que un script inyectado
  /// lee. La sesión es la cookie HttpOnly que pone el login y la clave la
  /// recuerda el gestor de contraseñas del navegador.
  AuthNotifier({
    required this.api,
    FlutterSecureStorage? storage,
    bool web = kIsWeb,
    this.renovarCada = const Duration(hours: 1),
  }) : _storage = web ? null : storage ?? almacenDelSistema,
       super(const AuthState());

  /// Llavero en macOS, archivo cifrado en Windows. En el Mac, el llavero
  /// clásico: la app va firmada «ad hoc» (sin equipo de Apple) y el de
  /// protección de datos exige el derecho keychain-access-groups, que esa
  /// firma no puede llevar; sin él respondía -34018 y la sesión y la clave
  /// recordada nunca quedaban guardadas.
  static const almacenDelSistema = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  /// Dos entradas y no cinco: la sesión y lo recordado, cada una un JSON.
  /// El llavero del Mac pregunta por entrada, y con cinco —token, id y
  /// nombre de la empresa, usuario y clave— salir y volver a entrar pedía
  /// la contraseña del llavero hasta tres veces (dueño, 2026-09-30). Van
  /// aparte porque viven distinto: salir borra la sesión y deja lo
  /// recordado.
  static const _kSesion = 'sesion';

  /// «Recordar contraseña»: usuario y clave, en el mismo almacén cifrado
  /// que la sesión y nunca en un archivo plano. Salir no los borra —para eso
  /// se recordaron—; los borra entrar con la casilla apagada.
  static const _kRecordar = 'recordar';

  /// Las cinco entradas de antes. Se leen solo si falta la nueva —leer una
  /// que no está no hace preguntar al llavero— y, si estaban, se pasan a la
  /// nueva y se borran. Así nadie pierde la sesión ni la clave recordada al
  /// actualizar, y no queda una clave suelta en el llavero.
  static const _kViejasSesion = [
    'auth_token',
    'auth_company_id',
    'auth_company_name',
  ];
  static const _kViejasRecordar = ['recordar_usuario', 'recordar_clave'];

  /// Lo último que se leyó o escribió en [_kRecordar] (null: no hay nada).
  /// Volver a entrar con la clave recordada no la reescribe: en el Mac,
  /// reescribir una entrada que dejó otro build vuelve a preguntar.
  ({String usuario, String clave})? _recordadas;
  bool _recordadasConocidas = false;
  final Duration renovarCada;
  Timer? _renovacionTimer;
  Future<void>? _renovando;

  /// A qué backend van el login y la validación. Puede cambiar con el panel
  /// abierto (`BackendSupervisor`): el provider la cambia aquí en vez de
  /// rehacer el notifier, que dejaba la sesión en «desconocida» y sacaba al
  /// operador al login aunque su token siguiera valiendo.
  AuthApi api;

  /// Null en el navegador.
  final FlutterSecureStorage? _storage;

  Future<void> restoreSession() async {
    if (_storage == null) return _restaurarDeCookie();
    String? token;
    String? companyId;
    String? companyName;
    try {
      final guardada = await _leer(_storage, _kSesion, _kViejasSesion, (
        viejas,
      ) {
        if (viejas.any((v) => v == null)) return null;
        return {
          'token': viejas[0]!,
          'companyId': viejas[1]!,
          'companyName': viejas[2]!,
        };
      });
      token = guardada?['token'];
      companyId = guardada?['companyId'];
      companyName = guardada?['companyName'];
    } catch (e) {
      // Si el almacén del sistema no se deja leer, no hay sesión que
      // restaurar: se pide la clave y ya. Sin este catch la excepción subía
      // sin dueño y la ventana se quedaba en el estado inicial para siempre.
      debugPrint('No se pudo leer la sesión guardada: $e');
    }
    if (token != null && companyId != null && companyName != null) {
      final sesionGuardada = AuthSession(
        token: token,
        companyId: companyId,
        companyName: companyName,
      );
      var sesion = sesionGuardada;
      // Renovar valida la sesión y extiende el token al mismo tiempo.
      try {
        sesion = await api.renovar(token);
        await _guardarSesion(sesion);
      } on SessionRevokedException {
        await _clearStored();
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      } catch (_) {
        // Sin red o 5xx se conserva el token vigente y se reintenta en una hora.
      }
      state = AuthState(status: AuthStatus.authenticated, session: sesion);
      _iniciarRenovacion();
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// En el navegador la sesión la dice el servidor por la cookie. Sin red no
  /// hay nada guardado con qué entrar, así que se pide la clave: el login
  /// dirá si es la red.
  Future<void> _restaurarDeCookie() async {
    AuthSession? sesion;
    try {
      sesion = await api.sesionActual();
    } catch (e) {
      debugPrint('No se pudo preguntar por la sesión: $e');
    }
    state = sesion == null
        ? const AuthState(status: AuthStatus.unauthenticated)
        : AuthState(status: AuthStatus.authenticated, session: sesion);
  }

  /// Lee la entrada [clave] como mapa de textos. Si no está, busca las
  /// [viejas]: si [armar] las junta, las pasa a [clave] y las borra.
  Future<Map<String, String>?> _leer(
    FlutterSecureStorage storage,
    String clave,
    List<String> viejas,
    Map<String, String>? Function(List<String?> viejas) armar,
  ) async {
    final texto = await storage.read(key: clave);
    if (texto != null) {
      final mapa = jsonDecode(texto);
      if (mapa is! Map) return null;
      return mapa.map((k, v) => MapEntry('$k', '$v'));
    }
    final valores = [for (final v in viejas) await storage.read(key: v)];
    if (valores.every((v) => v == null)) return null;
    final armado = armar(valores);
    if (armado != null) {
      await storage.write(key: clave, value: jsonEncode(armado));
    }
    for (final v in viejas) {
      await storage.delete(key: v);
    }
    return armado;
  }

  Future<void> _clearStored() async {
    final storage = _storage;
    if (storage == null) return;
    try {
      // Las viejas también: si el panel se actualizó con una sesión abierta
      // y se salió sin pasar por el arranque, quedarían con un token vivo.
      // Borrar una que no está no hace preguntar al llavero.
      for (final clave in [_kSesion, ..._kViejasSesion]) {
        await storage.delete(key: clave);
      }
    } catch (e) {
      debugPrint('No se pudo borrar la sesión guardada: $e');
    }
  }

  Future<void> _guardarSesion(AuthSession session) async {
    final storage = _storage;
    if (storage == null) return;
    try {
      await storage.write(
        key: _kSesion,
        value: jsonEncode({
          'token': session.token,
          'companyId': session.companyId,
          'companyName': session.companyName,
        }),
      );
    } catch (e) {
      debugPrint('No se pudo guardar la sesión renovada: $e');
    }
  }

  void _iniciarRenovacion() {
    _renovacionTimer?.cancel();
    if (_storage == null || state.session?.token == null) return;
    _renovacionTimer = Timer.periodic(renovarCada, (_) => renovarSesion());
  }

  Future<void> renovarSesion() =>
      _renovando ??= _renovarSesion().whenComplete(() {
        _renovando = null;
      });

  Future<void> _renovarSesion() async {
    final actual = state.session;
    if (actual?.token == null || state.status != AuthStatus.authenticated) {
      return;
    }
    try {
      final nueva = await api.renovar(actual!.token!);
      if (state.session?.token != actual.token) return;
      state = state.copyWith(session: nueva);
      await _guardarSesion(nueva);
    } on SessionRevokedException {
      _renovacionTimer?.cancel();
      await _clearStored();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (_) {
      // Fallos transitorios no invalidan el token guardado.
    }
  }

  /// Lo que se recordó en el último ingreso con la casilla encendida, o
  /// null. Si el almacén no se deja leer, es null y se escribe a mano. En
  /// el navegador siempre null: ahí recuerda el navegador.
  Future<({String usuario, String clave})?> credencialesRecordadas() async {
    final storage = _storage;
    if (storage == null) return null;
    try {
      final guardadas = await _leer(storage, _kRecordar, _kViejasRecordar, (
        viejas,
      ) {
        if (viejas.any((v) => v == null)) return null;
        return {'usuario': viejas[0]!, 'clave': viejas[1]!};
      });
      final usuario = guardadas?['usuario'];
      final clave = guardadas?['clave'];
      _recordadas = usuario == null || clave == null
          ? null
          : (usuario: usuario, clave: clave);
      _recordadasConocidas = true;
      return _recordadas;
    } catch (e) {
      debugPrint('No se pudo leer la contraseña recordada: $e');
      return null;
    }
  }

  Future<bool> login(
    String username,
    String password, {
    bool recordar = false,
  }) async {
    state = state.copyWith(loading: true, error: null);

    final AuthSession session;
    try {
      session = await api.login(username, password);
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
    // requisito para entrar. El almacén cifrado lo pone el sistema (en
    // Windows un archivo cifrado con la clave del usuario, en macOS el
    // Llavero) y puede negarse por permisos o por política de la máquina.
    //
    // Antes estas tres escrituras estaban dentro del mismo try que la
    // llamada de red, y su `catch` decía "No se pudo conectar con el
    // servidor": el panel rechazaba el ingreso con un mensaje que culpaba a
    // la red aunque el servidor hubiera contestado 200. Ahora, si el almacén
    // falla, se entra igual y lo único que se pierde es no tener que volver
    // a escribir la clave en el próximo arranque.
    final storage = _storage;
    if (storage == null) {
      state = AuthState(status: AuthStatus.authenticated, session: session);
      return true;
    }
    await _guardarSesion(session);
    // Solo tras un ingreso aceptado: una clave rechazada no se recuerda ni
    // borra la buena. Y, como la sesión, si el almacén se niega se entra
    // igual.
    final nuevas = recordar ? (usuario: username, clave: password) : null;
    try {
      if (!_recordadasConocidas || nuevas != _recordadas) {
        if (nuevas != null) {
          await storage.write(
            key: _kRecordar,
            value: jsonEncode({
              'usuario': nuevas.usuario,
              'clave': nuevas.clave,
            }),
          );
        } else {
          await storage.delete(key: _kRecordar);
          for (final v in _kViejasRecordar) {
            await storage.delete(key: v);
          }
        }
        _recordadas = nuevas;
        _recordadasConocidas = true;
      }
    } catch (e) {
      debugPrint('Se entró, pero no se pudo recordar la contraseña: $e');
    }

    state = AuthState(status: AuthStatus.authenticated, session: session);
    _iniciarRenovacion();
    return true;
  }

  /// Primero el servidor revoca el token y luego se borra aquí. Si el
  /// servidor no contesta, se sale igual: `AuthApi.logout` no lanza.
  Future<void> logout() async {
    _renovacionTimer?.cancel();
    _renovacionTimer = null;
    final session = state.session;
    if (session != null) await api.logout(session.token);
    await _clearStored();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  void dispose() {
    _renovacionTimer?.cancel();
    super.dispose();
  }
}

/// El login contra el backend actual: el que resolvió el arranque
/// (`main.dart`) o el respaldo si el túnel se cayó con el panel abierto.
final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(baseUrl: ref.watch(backendUrlProvider)),
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(api: ref.read(authApiProvider));
  ref.listen<AuthApi>(authApiProvider, (_, api) => notifier.api = api);
  return notifier;
});
