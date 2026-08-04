import '../../../core/api/api_client.dart';
import 'access_management_model.dart';

class AccessManagementApi {
  Future<AccessManagementOverview>
      getOverview() async {
    final response =
        await ApiClient.dio
            .get<Map<String, dynamic>>(
      '/access-management',
    );

    final data = response.data;

    if (data == null) {
      throw StateError(
        'Le serveur n’a retourné aucune donnée '
        'de gestion des accès.',
      );
    }

    return AccessManagementOverview.fromJson(data);
  }

  Future<void> updateGlobalPermissions({
    required String userId,
    required GlobalUserPermissionsUpdateRequest
        request,
  }) async {
    await ApiClient.dio.put<void>(
      '/access-management/users/'
      '$userId/permissions',
      data: request.toJson(),
    );
  }
}
