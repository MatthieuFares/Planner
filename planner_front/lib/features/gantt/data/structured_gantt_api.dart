import '../../../core/api/api_client.dart';
import 'structured_gantt_model.dart';

class StructuredGanttApi {
  Future<StructuredGanttResponse> getStructuredGantt(int projectId) async {
    final response = await ApiClient.dio.get(
      '/api/Gantt/structured/project/$projectId',
    );

    return StructuredGanttResponse.fromJson(response.data);
  }
}