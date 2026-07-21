import '../../../core/api/api_client.dart';
import 'resource_assignment_model.dart';

class ResourceAssignmentApi {
  Future<List<ResourceAssignment>>
      getAssignmentsByProject(
    int projectId,
  ) async {
    final response = await ApiClient.dio.get(
      '/ResourceAssignments/project/$projectId',
    );

    return _parseAssignments(response.data);
  }

  Future<List<ResourceAssignment>>
      getAssignmentsByTask(
    int taskId,
  ) async {
    final response = await ApiClient.dio.get(
      '/ResourceAssignments/task/$taskId',
    );

    return _parseAssignments(response.data);
  }

  Future<ResourceAssignment?> createAssignment(
    ResourceAssignmentCreateRequest request,
  ) async {
    final response = await ApiClient.dio.post(
      '/ResourceAssignments',
      data: request.toJson(),
    );

    return _parseAssignment(response.data);
  }

  Future<ResourceAssignment?> updateAssignment(
    int assignmentId,
    ResourceAssignmentUpdateRequest request,
  ) async {
    final response = await ApiClient.dio.put(
      '/ResourceAssignments/$assignmentId',
      data: request.toJson(),
    );

    return _parseAssignment(response.data);
  }

  Future<void> deleteAssignment(
    int assignmentId,
  ) async {
    await ApiClient.dio.delete(
      '/ResourceAssignments/$assignmentId',
    );
  }

  List<ResourceAssignment> _parseAssignments(
    dynamic rawData,
  ) {
    if (rawData is! List) {
      throw StateError(
        'Format de réponse invalide pour '
        'les assignations.',
      );
    }

    return rawData
        .whereType<Map>()
        .map(
          (json) => ResourceAssignment.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }

  ResourceAssignment? _parseAssignment(
    dynamic rawData,
  ) {
    if (rawData == null) return null;

    if (rawData is! Map) {
      throw StateError(
        'Format de réponse invalide pour '
        'l’assignation.',
      );
    }

    return ResourceAssignment.fromJson(
      Map<String, dynamic>.from(rawData),
    );
  }
}
