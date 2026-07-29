import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'project_calendar_exception_model.dart';

class ProjectCalendarExceptionApi {
  final Dio _dio;

  ProjectCalendarExceptionApi({Dio? dio})
      : _dio = dio ?? ApiClient.dio;

  Future<List<ProjectCalendarExceptionModel>> getByProjectId(
    int projectId,
  ) async {
    try {
      final response = await _dio.get(
        '/ProjectCalendarExceptions/project/$projectId',
      );

      final data = response.data as List<dynamic>;

      return data
          .map(
            (item) =>
                ProjectCalendarExceptionModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw Exception(
        'Erreur chargement exceptions calendrier : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }

  Future<ProjectCalendarExceptionModel> create({
    required int projectId,
    required ProjectCalendarExceptionModel exception,
  }) async {
    try {
      final response = await _dio.post(
        '/ProjectCalendarExceptions/project/$projectId',
        data: exception.toCreateJson(),
      );

      return ProjectCalendarExceptionModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur création exception calendrier : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }

  Future<void> delete(
    int exceptionId,
  ) async {
    try {
      await _dio.delete(
        '/ProjectCalendarExceptions/$exceptionId',
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur suppression exception calendrier : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }
}
