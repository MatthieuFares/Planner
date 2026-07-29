import 'package:dio/dio.dart';

import '../../features/auth/data/auth_session.dart';
import '../config/app_config.dart';

class ApiClient {
  static final Dio dio = _buildDio();

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const <String, dynamic>{
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (
          RequestOptions options,
          RequestInterceptorHandler handler,
        ) async {
          if (options.extra['skipAuth'] == true) {
            handler.next(options);
            return;
          }

          final accessToken =
              await AuthSession.instance
                  .getValidAccessToken();

          if (accessToken != null &&
              accessToken.isNotEmpty) {
            options.headers['Authorization'] =
                'Bearer $accessToken';
          }

          handler.next(options);
        },
        onError: (
          DioException error,
          ErrorInterceptorHandler handler,
        ) async {
          final request = error.requestOptions;
          final isUnauthorized =
              error.response?.statusCode == 401;
          final wasAlreadyRetried =
              request.extra['authRetried'] == true;

          if (!isUnauthorized) {
            handler.next(error);
            return;
          }

          if (wasAlreadyRetried) {
            await AuthSession.instance.logout();
            handler.next(error);
            return;
          }

          final refreshed =
              await AuthSession.instance
                  .refreshTokens(force: true);

          if (!refreshed) {
            handler.next(error);
            return;
          }

          final accessToken =
              await AuthSession.instance
                  .getValidAccessToken();

          if (accessToken == null ||
              accessToken.isEmpty) {
            handler.next(error);
            return;
          }

          // Un FormData déjà envoyé ne peut pas toujours être rejoué
          // proprement par Dio. Le rafraîchissement proactif du jeton
          // évite normalement ce cas pour les imports.
          if (request.data is FormData) {
            handler.next(error);
            return;
          }

          final retryRequest = request.copyWith(
            headers: <String, dynamic>{
              ...request.headers,
              'Authorization': 'Bearer $accessToken',
            },
            extra: <String, dynamic>{
              ...request.extra,
              'authRetried': true,
            },
          );

          try {
            final response =
                await dio.fetch<dynamic>(retryRequest);

            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.next(retryError);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );

    return dio;
  }
}
