import '../../../core/api/api_client.dart';
import 'resource_assignment_model.dart';

class ResourceAssignmentApi {
  Future<List<ResourceAssignment>> getAssignmentsByTask(int taskId) async {
    final response = await ApiClient.dio.get(
      '/ResourceAssignments/task/$taskId',
    );

    final List<dynamic> data = response.data;

    return data
        .map((json) => ResourceAssignment.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> createAssignment(
    ResourceAssignmentCreateRequest request,
  ) async {
    await ApiClient.dio.post(
      '/ResourceAssignments',
      data: request.toJson(),
    );
  }

  Future<void> updateAssignment(
    int assignmentId,
    ResourceAssignmentUpdateRequest request,
  ) async {
    await ApiClient.dio.put(
      '/ResourceAssignments/$assignmentId',
      data: request.toJson(),
    );
  }

  Future<void> deleteAssignment(int assignmentId) async {
    await ApiClient.dio.delete('/ResourceAssignments/$assignmentId');
  }
}