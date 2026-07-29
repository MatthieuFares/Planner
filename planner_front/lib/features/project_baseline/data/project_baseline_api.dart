import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'project_baseline_model.dart';

class ProjectBaselineApi {
  final Dio _dio;

  ProjectBaselineApi({Dio? dio})
      : _dio = dio ?? ApiClient.dio;

  Future<List<ProjectBaselineModel>> getByProjectId(
    int projectId,
  ) async {
    try {
      final response = await _dio.get(
        '/ProjectBaselines/project/$projectId',
      );

      final data = response.data as List<dynamic>;

      return data
          .map(
            (item) => ProjectBaselineModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw Exception(
        'Erreur chargement baselines : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }

  Future<ProjectBaselineDetailModel> create({
    required int projectId,
    required String name,
    String? description,
    bool setAsActive = true,
  }) async {
    try {
      final response = await _dio.post(
        '/ProjectBaselines/project/$projectId',
        data: {
          'name': name,
          'description': description,
          'setAsActive': setAsActive,
        },
      );

      return ProjectBaselineDetailModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur création baseline : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }

  Future<ProjectBaselineDetailModel> getById(
    int baselineId,
  ) async {
    try {
      final response = await _dio.get(
        '/ProjectBaselines/$baselineId',
      );

      return ProjectBaselineDetailModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur détail baseline : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }

  Future<ProjectBaselineComparisonModel> compare(
    int baselineId,
  ) async {
    try {
      final response = await _dio.get(
        '/ProjectBaselines/$baselineId/comparison',
      );

      return ProjectBaselineComparisonModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur comparaison baseline : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }

  Future<ProjectBaselineModel> setActive(
    int baselineId,
  ) async {
    try {
      final response = await _dio.put(
        '/ProjectBaselines/$baselineId/set-active',
      );

      return ProjectBaselineModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur activation baseline : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }

  Future<void> delete(
    int baselineId,
  ) async {
    try {
      await _dio.delete(
        '/ProjectBaselines/$baselineId',
      );
    } on DioException catch (error) {
      throw Exception(
        'Erreur suppression baseline : '
        '${error.response?.statusCode} - '
        '${error.response?.data ?? error.message}',
      );
    }
  }
}
