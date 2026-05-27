import '../../../core/api/api_client.dart';
import 'resource_group_model.dart';

class ResourceGroupApi {
  Future<List<ResourceGroup>> getGroups() async {
    final response = await ApiClient.dio.get('/ResourceGroups');

    final List<dynamic> data = response.data;

    return data
        .map((json) => ResourceGroup.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ResourceGroup> getGroupById(int groupId) async {
    final response = await ApiClient.dio.get('/ResourceGroups/$groupId');

    return ResourceGroup.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ResourceGroupMember>> getMembers(int groupId) async {
    final response = await ApiClient.dio.get(
      '/ResourceGroups/$groupId/members',
    );

    final List<dynamic> data = response.data;

    return data
        .map(
          (json) => ResourceGroupMember.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> createGroup(ResourceGroupCreateRequest request) async {
    await ApiClient.dio.post(
      '/ResourceGroups',
      data: request.toJson(),
    );
  }

  Future<void> updateGroup(
    int groupId,
    ResourceGroupUpdateRequest request,
  ) async {
    await ApiClient.dio.put(
      '/ResourceGroups/$groupId',
      data: request.toJson(),
    );
  }

  Future<void> deleteGroup(int groupId) async {
    await ApiClient.dio.delete('/ResourceGroups/$groupId');
  }

  Future<void> addMember(ResourceGroupMemberRequest request) async {
    await ApiClient.dio.post(
      '/ResourceGroups/members',
      data: request.toJson(),
    );
  }

  Future<void> removeMember({
    required int groupId,
    required int resourceId,
  }) async {
    await ApiClient.dio.delete(
      '/ResourceGroups/$groupId/members/$resourceId',
    );
  }
}