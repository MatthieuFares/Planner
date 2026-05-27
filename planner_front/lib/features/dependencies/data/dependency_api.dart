import '../../../core/api/api_client.dart';
import 'dependency_model.dart';

class DependencyApi {
  Future<List<TaskDependency>> getDependenciesByTask(int taskId) async {
    final response = await ApiClient.dio.get('/TaskDependencies/task/$taskId');

    final List<dynamic> data = response.data;

    return data
        .map((json) => TaskDependency.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> createDependency(DependencyCreateRequest request) async {
    await ApiClient.dio.post(
      '/TaskDependencies',
      data: request.toJson(),
    );
  }

  Future<void> updateDependency(
    int dependencyId,
    DependencyUpdateRequest request,
  ) async {
    await ApiClient.dio.put(
      '/TaskDependencies/$dependencyId',
      data: request.toJson(),
    );
  }

  Future<void> deleteDependency(int dependencyId) async {
    await ApiClient.dio.delete('/TaskDependencies/$dependencyId');
  }
}