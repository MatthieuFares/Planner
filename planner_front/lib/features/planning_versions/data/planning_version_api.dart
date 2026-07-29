import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'planning_version_model.dart';

class PlanningVersionApi {
  final Dio _dio;

  PlanningVersionApi({Dio? dio})
      : _dio = dio ?? ApiClient.dio;

  Future<List<PlanningVersionSummaryModel>> getByProjectId(
    int projectId,
  ) async {
    try {
      final response = await _dio.get(
        '/PlanningVersions/project/$projectId',
      );

      final data = response.data as List<dynamic>;

      return data
          .map(
            (item) => PlanningVersionSummaryModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw Exception(
        _buildErrorMessage(
          'Erreur chargement des versions',
          error,
        ),
      );
    }
  }

  Future<PlanningVersionSummaryModel> create({
    required int projectId,
    required String name,
    String? description,
    String? createdBy,
  }) async {
    try {
      final response = await _dio.post(
        '/PlanningVersions/project/$projectId',
        data: {
          'name': name,
          'description': description,
          'createdBy': createdBy,
        },
      );

      return PlanningVersionSummaryModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        _buildErrorMessage(
          'Erreur création de la version',
          error,
        ),
      );
    }
  }

  Future<PlanningVersionDetailModel> getById(
    int versionId,
  ) async {
    try {
      final response = await _dio.get(
        '/PlanningVersions/$versionId',
      );

      return PlanningVersionDetailModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        _buildErrorMessage(
          'Erreur chargement du détail de la version',
          error,
        ),
      );
    }
  }

  Future<PlanningVersionComparisonModel> compareWithCurrent(
    int versionId,
  ) async {
    try {
      final response = await _dio.get(
        '/PlanningVersions/$versionId/compare-current',
      );

      return PlanningVersionComparisonModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        _buildErrorMessage(
          'Erreur comparaison de la version',
          error,
        ),
      );
    }
  }

  Future<RestorePlanningVersionResponseModel> restore({
    required int versionId,
    required bool confirmRestore,
    bool createSafetyVersion = true,
    String? safetyVersionName,
    String? restoredBy,
  }) async {
    try {
      final response = await _dio.post(
        '/PlanningVersions/$versionId/restore',
        data: {
          'confirmRestore': confirmRestore,
          'createSafetyVersion': createSafetyVersion,
          'safetyVersionName': safetyVersionName,
          'restoredBy': restoredBy,
        },
      );

      return RestorePlanningVersionResponseModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(
        _buildErrorMessage(
          'Erreur restauration de la version',
          error,
        ),
      );
    }
  }

  Future<void> delete(
    int versionId,
  ) async {
    try {
      await _dio.delete(
        '/PlanningVersions/$versionId',
      );
    } on DioException catch (error) {
      throw Exception(
        _buildErrorMessage(
          'Erreur suppression de la version',
          error,
        ),
      );
    }
  }

  String _buildErrorMessage(
    String prefix,
    DioException error,
  ) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    final detail =
        responseData ?? error.message ?? 'Erreur inconnue';

    if (statusCode == null) {
      return '$prefix : $detail';
    }

    return '$prefix : $statusCode - $detail';
  }
}
