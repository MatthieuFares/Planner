import '../../../core/api/api_client.dart';
import 'project_access_model.dart';

class ProjectAccessApi {
  Future<ProjectAccessModel> getProjectAccess(
    int projectId,
  ) async {
    final response = await ApiClient.dio.get(
      '/projects/$projectId/access',
    );

    return ProjectAccessModel.fromJson(
      Map<String, dynamic>.from(
        response.data as Map,
      ),
    );
  }
}
