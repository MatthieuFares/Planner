import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';

class AuthApi {
  final Dio _dio;

  AuthApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                headers: const <String, dynamic>{
                  'Accept': 'application/json',
                },
              ),
            );

  Future<AuthTokenResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        queryParameters: const <String, dynamic>{
          'useCookies': false,
        },
        data: <String, dynamic>{
          'email': email.trim(),
          'password': password,
        },
      );

      final data = response.data;

      if (data == null) {
        throw const AuthException(
          'Le serveur n’a retourné aucun jeton de connexion.',
        );
      }

      return AuthTokenResponse.fromJson(data);
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        invalidCredentialsMessage:
            'Adresse e-mail ou mot de passe incorrect.',
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      await _dio.post<void>(
        '/auth/register',
        data: <String, dynamic>{
          'email': email.trim(),
          'password': password,
        },
      );
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        invalidCredentialsMessage:
            'L’inscription n’a pas pu être effectuée.',
      );
    }
  }

  Future<AuthTokenResponse> refresh({
    required String refreshToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, dynamic>{
          'refreshToken': refreshToken,
        },
      );

      final data = response.data;

      if (data == null) {
        throw const AuthException(
          'Le serveur n’a retourné aucun nouveau jeton.',
          shouldClearSession: true,
        );
      }

      return AuthTokenResponse.fromJson(data);
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        invalidCredentialsMessage:
            'La session a expiré. Reconnectez-vous.',
        clearSessionOnAuthorizationFailure: true,
      );
    }
  }

  AuthException _mapDioException(
    DioException error, {
    required String invalidCredentialsMessage,
    bool clearSessionOnAuthorizationFailure = false,
  }) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

  if (statusCode == 401 || statusCode == 403) {
    return AuthException(
      invalidCredentialsMessage,
      shouldClearSession:
          clearSessionOnAuthorizationFailure,
    );
  }

  if (statusCode == 400 || statusCode == 409) {
    return AuthException(
      _extractServerMessage(data) ??
          invalidCredentialsMessage,
      shouldClearSession:
          clearSessionOnAuthorizationFailure,
    );
  }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const AuthException(
        'Connexion à l’API impossible. Vérifiez que le serveur est démarré.',
      );
    }

    return AuthException(
      _extractServerMessage(data) ??
          'Une erreur est survenue pendant l’authentification.',
    );
  }

  String? _extractServerMessage(dynamic data) {
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    if (data is Map) {
      for (final key in const <String>[
        'message',
        'detail',
        'error',
        'title',
      ]) {
        final value = data[key];

        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }

      final errors = data['errors'];

      if (errors is Map) {
        final messages = <String>[];

        for (final value in errors.values) {
          if (value is List) {
            messages.addAll(
              value
                  .map((item) => item.toString().trim())
                  .where((message) => message.isNotEmpty),
            );
          } else if (value is String &&
              value.trim().isNotEmpty) {
            messages.add(value.trim());
          }
        }

        if (messages.isNotEmpty) {
          return messages.join(' ');
        }
      }
    }

    return null;
  }
}

class AuthTokenResponse {
  final String tokenType;
  final String accessToken;
  final int expiresIn;
  final String refreshToken;

  const AuthTokenResponse({
    required this.tokenType,
    required this.accessToken,
    required this.expiresIn,
    required this.refreshToken,
  });

  factory AuthTokenResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final tokenType =
        json['tokenType']?.toString().trim();
    final accessToken =
        json['accessToken']?.toString().trim();
    final refreshToken =
        json['refreshToken']?.toString().trim();

    final rawExpiresIn = json['expiresIn'];
    final expiresIn = rawExpiresIn is num
        ? rawExpiresIn.toInt()
        : int.tryParse(rawExpiresIn?.toString() ?? '');

    if (tokenType == null ||
        tokenType.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        expiresIn == null ||
        expiresIn <= 0) {
      throw const AuthException(
        'La réponse d’authentification du serveur est invalide.',
      );
    }

    return AuthTokenResponse(
      tokenType: tokenType,
      accessToken: accessToken,
      expiresIn: expiresIn,
      refreshToken: refreshToken,
    );
  }
}

class AuthException implements Exception {
  final String message;
  final bool shouldClearSession;

  const AuthException(
    this.message, {
    this.shouldClearSession = false,
  });

  @override
  String toString() => message;
}
