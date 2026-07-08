import '../../../core/api/api_client.dart';
import 'resource_analysis_model.dart';

class ResourceAnalysisApi {
  Future<ProjectResourceAnalysis> getProjectAnalysis(int projectId) async {
    final response = await ApiClient.dio.get(
      '/ResourceAnalysis/project/$projectId',
    );

    return ProjectResourceAnalysis.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}