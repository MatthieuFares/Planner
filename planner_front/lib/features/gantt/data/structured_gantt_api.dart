import '../../../core/api/api_client.dart';
import 'structured_gantt_model.dart';

class StructuredGanttApi {
  Future<StructuredGanttResponse> getStructuredGantt(int projectId) async {
    final response = await ApiClient.dio.get(
      '/Gantt/project/$projectId/structured',
    );

    return StructuredGanttResponse.fromJson(response.data);
  }
}