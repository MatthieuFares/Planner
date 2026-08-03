import '../../../core/api/api_client.dart';
import 'project_member_model.dart';

class ProjectMemberApi {
  Future<List<ProjectMemberModel>> getMembers(
    int projectId,
  ) async {
    final response = await ApiClient.dio.get<List<dynamic>>(
      '/projects/$projectId/members',
    );

    final data = response.data ?? const <dynamic>[];

    return data
        .whereType<Map>()
        .map(
          (json) => ProjectMemberModel.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }

  Future<ProjectMemberModel> addMember({
    required int projectId,
    required ProjectMemberCreateRequest request,
  }) async {
    final response =
        await ApiClient.dio.post<Map<String, dynamic>>(
      '/projects/$projectId/members',
      data: request.toJson(),
    );

    final data = response.data;

    if (data == null) {
      throw StateError(
        'Le serveur n’a retourné aucun membre.',
      );
    }

    return ProjectMemberModel.fromJson(data);
  }

  Future<ProjectMemberModel> updateMember({
    required int projectId,
    required int memberId,
    required ProjectMemberUpdateRequest request,
  }) async {
    final response =
        await ApiClient.dio.put<Map<String, dynamic>>(
      '/projects/$projectId/members/$memberId',
      data: request.toJson(),
    );

    final data = response.data;

    if (data == null) {
      throw StateError(
        'Le serveur n’a retourné aucun membre.',
      );
    }

    return ProjectMemberModel.fromJson(data);
  }

  Future<void> removeMember({
    required int projectId,
    required int memberId,
  }) async {
    await ApiClient.dio.delete<void>(
      '/projects/$projectId/members/$memberId',
    );
  }
}
