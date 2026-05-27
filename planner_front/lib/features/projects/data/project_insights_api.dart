import '../../../core/api/api_client.dart';

class ProjectInsightsApi {
  Future<Map<String, dynamic>> getSummary(int projectId) async {
    try {
      final response = await ApiClient.dio.get('/projects/$projectId/summary');

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }

      return {
        'value': response.data,
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<dynamic>> getWarnings(int projectId) async {
    try {
      final response = await ApiClient.dio.get('/projects/$projectId/warnings');

      if (response.data is List<dynamic>) {
        return response.data as List<dynamic>;
      }

      return [response.data];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getResourceAnalysis(int projectId) async {
    try {
      final response = await ApiClient.dio.get(
        '/ResourceAnalysis/project/$projectId',
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }

      return {
        'value': response.data,
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<dynamic>> getGantt(int projectId) async {
    try {
      final response = await ApiClient.dio.get('/Gantt/project/$projectId');

      if (response.data is List<dynamic>) {
        return response.data as List<dynamic>;
      }

      return [response.data];
    } catch (_) {
      return [];
    }
  }
}