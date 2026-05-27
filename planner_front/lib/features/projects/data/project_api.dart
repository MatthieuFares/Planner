import '../../../core/api/api_client.dart';
import 'project_model.dart';

class ProjectApi {
  Future<List<Project>> getProjects() async {
    final response = await ApiClient.dio.get('/Projects');

    final List<dynamic> data = response.data;

    return data
        .map((json) => Project.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Project> getProjectById(int projectId) async {
    final response = await ApiClient.dio.get('/Projects/$projectId');

    return Project.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Project> createProject(ProjectCreateRequest request) async {
    final response = await ApiClient.dio.post(
      '/Projects',
      data: request.toJson(),
    );

    return Project.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateProject(int projectId, ProjectUpdateRequest request) async {
    await ApiClient.dio.put(
      '/Projects/$projectId',
      data: request.toJson(),
    );
  }

  Future<void> deleteProject(int projectId) async {
    await ApiClient.dio.delete('/Projects/$projectId');
  }
}