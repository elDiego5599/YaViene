import 'package:dio/dio.dart';

import '../../../../config.dart';
import '../domain/auth_session.dart';

class AuthApi {
  AuthApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.backendUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ));

  final Dio _dio;

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
      final message = e.response?.data?['error']?['message'] as String?;
      switch (e.response?.statusCode) {
        case 429:
          throw AuthApiException('Demasiados intentos. Espera un momento.');
        case 401:
          throw AuthApiException('Usuario o contraseña incorrectos.');
        default:
          throw AuthApiException(message ?? 'No se pudo conectar con el servidor.');
      }
    }
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
