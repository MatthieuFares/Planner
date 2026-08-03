import '../../../core/api/api_client.dart';
import 'project_model.dart';

class ProjectApi {
  Future<ProjectListResult> getProjectList() async {
    final response =
        await ApiClient.dio.get<Map<String, dynamic>>(
      '/Projects/list',
    );

    final data = response.data;

    if (data == null) {
      throw StateError(
        'Le serveur n’a retourné aucune liste de projets.',
      );
    }

    return ProjectListResult.fromJson(data);
  }

  Future<List<Project>> getProjects() async {
    final response =
        await ApiClient.dio.get<List<dynamic>>(
      '/Projects',
    );

    final data =
        response.data ?? const <dynamic>[];

    return data
        .whereType<Map>()
        .map(
          (json) => Project.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }

  Future<Project> getProjectById(
    int projectId,
  ) async {
    final response =
        await ApiClient.dio.get<Map<String, dynamic>>(
      '/Projects/$projectId',
    );

    final data = response.data;

    if (data == null) {
      throw StateError(
        'Le serveur n’a retourné aucun projet.',
      );
    }

    return Project.fromJson(data);
  }

  Future<Project> createProject(
    ProjectCreateRequest request,
  ) async {
    final response =
        await ApiClient.dio.post<Map<String, dynamic>>(
      '/Projects',
      data: request.toJson(),
    );

    final data = response.data;

    if (data == null) {
      throw StateError(
        'Le serveur n’a retourné aucun projet créé.',
      );
    }

    return Project.fromJson(data);
  }

  Future<void> updateProject(
    int projectId,
    ProjectUpdateRequest request,
  ) async {
    await ApiClient.dio.put<void>(
      '/Projects/$projectId',
      data: request.toJson(),
    );
  }

  Future<void> deleteProject(
    int projectId,
  ) async {
    await ApiClient.dio.delete<void>(
      '/Projects/$projectId',
    );
  }
}
