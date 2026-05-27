import '../../../core/api/api_client.dart';
import 'task_model.dart';

class TaskApi {
  Future<List<PlannerTask>> getTasksByProject(int projectId) async {
    final response = await ApiClient.dio.get('/Projects/$projectId/tasks');

    final List<dynamic> data = response.data;

    return data
        .map((json) => PlannerTask.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<PlannerTask> createTask(TaskCreateRequest request) async {
    final response = await ApiClient.dio.post(
      '/Tasks',
      data: request.toJson(),
    );

    return PlannerTask.fromJson(response.data as Map<String, dynamic>);
  }

Future<void> updateTask(int taskId, TaskUpdateRequest request) async {
  await ApiClient.dio.put(
    '/Tasks/$taskId',
    data: request.toJson(),
  );
}

  Future<void> deleteTask(int taskId) async {
    await ApiClient.dio.delete('/Tasks/$taskId');
  }
}