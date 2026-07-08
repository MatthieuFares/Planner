import '../../../core/api/api_client.dart';

class ProjectInsightsApi {
  Future<Map<String, dynamic>> getSummary(int projectId) async {
    final response = await ApiClient.dio.get('/projects/$projectId/summary');

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    return {
      'value': response.data,
    };
  }

  Future<List<dynamic>> getWarnings(int projectId) async {
    final response = await ApiClient.dio.get('/projects/$projectId/warnings');

    if (response.data is List<dynamic>) {
      return response.data as List<dynamic>;
    }

    return [response.data];
  }

  Future<Map<String, dynamic>> getResourceAnalysis(int projectId) async {
    final response = await ApiClient.dio.get(
      '/ResourceAnalysis/project/$projectId',
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    return {
      'value': response.data,
    };
  }

  Future<List<dynamic>> getGantt(int projectId) async {
    final response = await ApiClient.dio.get('/Gantt/project/$projectId');

    if (response.data is List<dynamic>) {
      return response.data as List<dynamic>;
    }

    return [response.data];
  }
}