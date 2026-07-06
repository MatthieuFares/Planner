import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import 'project_calendar_model.dart';

class ProjectCalendarApi {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  Future<ProjectCalendarModel> getByProjectId(int projectId) async {
    try {
      final response = await _dio.get(
        '/ProjectCalendars/project/$projectId',
      );

      return ProjectCalendarModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur chargement calendrier projet : '
        '${error.response?.statusCode} - ${error.response?.data ?? error.message}',
      );
    }
  }

  Future<ProjectCalendarModel> updateByProjectId({
    required int projectId,
    required ProjectCalendarModel calendar,
  }) async {
    try {
      final response = await _dio.put(
        '/ProjectCalendars/project/$projectId',
        data: calendar.toUpdateJson(),
      );

      return ProjectCalendarModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur mise à jour calendrier projet : '
        '${error.response?.statusCode} - ${error.response?.data ?? error.message}',
      );
    }
  }
}