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

    if (statusCode == 401 ||
        statusCode == 403) {
      // Les endpoints Identity peuvent retourner le titre générique
      // « Failed ». Pour la connexion, on garde un message fonctionnel.
      return AuthException(
        invalidCredentialsMessage,
        shouldClearSession:
            clearSessionOnAuthorizationFailure,
      );
    }

    if (statusCode == 400 ||
        statusCode == 409) {
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
      return _translateIdentityError(
        code: '',
        message: data.trim(),
      );
    }

    if (data is Map) {
      // ASP.NET Identity place les causes précises dans "errors".
      // Elles sont prioritaires sur le titre générique anglais.
      final errors = data['errors'];

      if (errors is Map) {
        final messages = <String>{};

        for (final entry in errors.entries) {
          final code = entry.key.toString();
          final value = entry.value;

          if (value is List) {
            for (final item in value) {
              final rawMessage =
                  item.toString().trim();

              if (rawMessage.isEmpty) continue;

              messages.add(
                _translateIdentityError(
                  code: code,
                  message: rawMessage,
                ),
              );
            }
          } else if (value is String &&
              value.trim().isNotEmpty) {
            messages.add(
              _translateIdentityError(
                code: code,
                message: value.trim(),
              ),
            );
          }
        }

        if (messages.isNotEmpty) {
          return messages.join(' ');
        }
      }

      for (final key in const <String>[
        'message',
        'detail',
        'error',
      ]) {
        final value = data[key];

        if (value is String &&
            value.trim().isNotEmpty) {
          return _translateIdentityError(
            code: key,
            message: value.trim(),
          );
        }
      }

      final title = data['title'];

      if (title is String &&
          title.trim().isNotEmpty &&
          title.trim() !=
              'One or more validation errors occurred.') {
        return _translateIdentityError(
          code: 'title',
          message: title.trim(),
        );
      }
    }

    return null;
  }

  String _translateIdentityError({
    required String code,
    required String message,
  }) {
    final normalizedCode = code.toLowerCase();
    final normalizedMessage = message.toLowerCase();

    if (normalizedCode.contains('duplicateemail') ||
        normalizedCode.contains('duplicateusername') ||
        normalizedMessage.contains('already taken') ||
        normalizedMessage.contains('already registered')) {
      return 'Un compte utilise déjà cette adresse e-mail.';
    }

    if (normalizedCode.contains('invalidemail') ||
        normalizedMessage.contains('email is invalid')) {
      return 'L’adresse e-mail est invalide.';
    }

    if (normalizedCode.contains('passwordtooshort') ||
        normalizedMessage.contains('passwords must be at least')) {
      return 'Le mot de passe doit contenir au moins 10 caractères.';
    }

    if (normalizedCode.contains(
          'passwordrequiresnonalphanumeric',
        ) ||
        normalizedMessage.contains('non alphanumeric')) {
      return 'Le mot de passe doit contenir au moins '
          'un caractère spécial.';
    }

    if (normalizedCode.contains('passwordrequiresdigit') ||
        normalizedMessage.contains('at least one digit')) {
      return 'Le mot de passe doit contenir au moins un chiffre.';
    }

    if (normalizedCode.contains('passwordrequireslower') ||
        normalizedMessage.contains('at least one lowercase')) {
      return 'Le mot de passe doit contenir au moins '
          'une lettre minuscule.';
    }

    if (normalizedCode.contains('passwordrequiresupper') ||
        normalizedMessage.contains('at least one uppercase')) {
      return 'Le mot de passe doit contenir au moins '
          'une lettre majuscule.';
    }

    if (normalizedMessage == 'failed') {
      return 'L’opération d’authentification a échoué.';
    }

    return message;
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
