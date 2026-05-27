import '../../../core/api/api_client.dart';
import 'resource_model.dart';

class ResourceApi {
  Future<List<Resource>> getResources() async {
    final response = await ApiClient.dio.get('/Resources');

    final List<dynamic> data = response.data;

    return data
        .map((json) => Resource.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Resource> getResourceById(int resourceId) async {
    final response = await ApiClient.dio.get('/Resources/$resourceId');

    return Resource.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> createResource(ResourceCreateRequest request) async {
    await ApiClient.dio.post(
      '/Resources',
      data: request.toJson(),
    );
  }

  Future<void> updateResource(
    int resourceId,
    ResourceUpdateRequest request,
  ) async {
    await ApiClient.dio.put(
      '/Resources/$resourceId',
      data: request.toJson(),
    );
  }

  Future<void> deleteResource(int resourceId) async {
    await ApiClient.dio.delete('/Resources/$resourceId');
  }
}