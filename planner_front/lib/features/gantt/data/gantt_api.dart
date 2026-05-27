import '../../../core/api/api_client.dart';
import 'gantt_task_model.dart';

class GanttApi {
  Future<List<GanttTask>> getProjectGantt(int projectId) async {
    final response = await ApiClient.dio.get('/Gantt/project/$projectId');

    final List<dynamic> data = response.data;

    return data
        .map((json) => GanttTask.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}