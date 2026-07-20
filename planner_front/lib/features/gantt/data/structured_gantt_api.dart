import '../../../core/api/api_client.dart';
import 'structured_gantt_model.dart';

class StructuredGanttApi {
  Future<StructuredGanttResponse> getStructuredGantt(int projectId) async {
    final response = await ApiClient.dio.get(
      '/Gantt/project/$projectId/structured',
    );

    return StructuredGanttResponse.fromJson(response.data);
  }

  Future<void> syncProjectTasks(int projectId) async {
    await ApiClient.dio.post(
      '/PlanningItems/project/$projectId/sync-tasks',
    );
  }

  Future<void> movePlanningItem({
    required int itemId,
    required int? newParentId,
  }) async {
    await ApiClient.dio.post(
      '/PlanningItems/$itemId/move',
      data: {
        'newParentId': newParentId,
      },
    );
  }

  Future<void> createPlanningItem({
    required int projectId,
    required String name,
    required String type,
    required int sortOrder,
    int? parentId,
  }) async {
    await ApiClient.dio.post(
      '/PlanningItems',
      data: {
        'projectId': projectId,
        'parentId': parentId,
        'name': name,
        'type': type,
        'sortOrder': sortOrder,
        'taskId': null,
      },
    );
  }
}
