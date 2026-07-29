import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'project_calendar_period_model.dart';

class ProjectCalendarPeriodApi {
  final Dio _dio;

  ProjectCalendarPeriodApi({Dio? dio})
      : _dio = dio ?? ApiClient.dio;

  Future<List<ProjectCalendarPeriodModel>> getByProjectId(
    int projectId,
  ) async {
    try {
      final response = await _dio.get(
        '/ProjectCalendarPeriods/project/$projectId',
      );

      final data = response.data as List<dynamic>;

      return data
          .map(
            (item) => ProjectCalendarPeriodModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw Exception(
        'Erreur chargement périodes calendrier : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }

  Future<ProjectCalendarPeriodModel> create({
    required int projectId,
    required ProjectCalendarPeriodModel period,
  }) async {
    try {
      final response = await _dio.post(
        '/ProjectCalendarPeriods/project/$projectId',
        data: period.toCreateJson(),
      );

      return ProjectCalendarPeriodModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur création période calendrier : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }

  Future<ProjectCalendarPeriodModel> update({
    required int periodId,
    required ProjectCalendarPeriodModel period,
  }) async {
    try {
      final response = await _dio.put(
        '/ProjectCalendarPeriods/$periodId',
        data: period.toUpdateJson(),
      );

      return ProjectCalendarPeriodModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur modification période calendrier : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }

  Future<void> delete(
    int periodId,
  ) async {
    try {
      await _dio.delete(
        '/ProjectCalendarPeriods/$periodId',
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur suppression période calendrier : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }
}
