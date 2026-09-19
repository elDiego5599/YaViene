import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/auth_session.dart';

class AuthApi {
  /// [baseUrl] es el backend que resolvió el arranque (`backendUrlProvider`),
  /// no `AppConfig.backendUrl`: si el túnel no contestó y el panel entró por
  /// el respaldo, el login tiene que ir al mismo sitio.
  AuthApi({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ));

  final Dio _dio;

  /// A qué backend pregunta.
  String get baseUrl => _dio.options.baseUrl;

  Future<AuthSession> login(String username, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/admin/login',
        data: {'username': username, 'password': password},
      );
      final data = response.data!;
      final company = Map<String, dynamic>.from(data['company'] as Map);
      return AuthSession(
        token: data['token'] as String,
        companyId: company['companyId'] as String,
        companyName: company['name'] as String,
      );
    } on DioException catch (e) {
      switch (e.response?.statusCode) {
        case 429:
          throw const AuthApiException('Demasiados intentos. Espera un momento.');
        case 401:
          throw const AuthApiException('Usuario o contraseña incorrectos.');
        default:
          throw AuthApiException(_mensajeDeFallo(e));
      }
    }
  }

  /// Un fallo sin respuesta es que no se llegó al servidor; uno con respuesta
  /// es que el servidor contestó algo que no esperábamos. Decir siempre "no se
  /// pudo conectar" manda a revisar la red cuando el problema está en la otra
  /// punta, y esconde el mensaje que el propio backend haya devuelto.
  String _mensajeDeFallo(DioException e) {
    final respuesta = e.response;
    if (respuesta == null) {
      return 'No se pudo conectar con el servidor.';
    }
    final datos = respuesta.data;
    if (datos is Map) {
      final error = datos['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
    }
    return 'El servidor respondió algo inesperado (${respuesta.statusCode}).';
  }
  Future<bool> validateSession(String token) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/fleet/routes',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return false;
      rethrow;
    }
  }

  /// Pide al servidor que revoque [token]. Borrarlo solo en este equipo lo
  /// dejaba vivo hasta que caducara (8 h) para quien lo hubiera copiado.
  ///
  /// Revoca todas las sesiones de la cuenta, no solo esta: el servidor sube
  /// la versión de la credencial, como al cambiar la contraseña, y cualquier
  /// otro equipo abierto con el mismo usuario vuelve a pedir la clave.
  ///
  /// No lanza nunca: sin red, o con un token que el servidor ya no reconoce,
  /// cerrar sesión en este equipo tiene que funcionar igual. Espera como
  /// mucho 3 s y no los 8 del cliente: quien pulsa «salir» sin red no tiene
  /// por qué quedarse mirando el tablero.
  Future<void> logout(String token) async {
    try {
      await _dio
          .post<void>(
            '/api/fleet/logout',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('El servidor no confirmó el cierre de sesión: $e');
    }
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
