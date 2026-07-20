import '../../dependencies/data/dependency_model.dart';
import '../../resources/data/resource_assignment_model.dart';
import '../data/task_model.dart';

class TaskEditResult {
  final TaskUpdateRequest taskRequest;
  final int parentId;

  final List<int> dependencyIdsToDelete;
  final List<TaskDependencyUpdateAction> dependenciesToUpdate;
  final List<DependencyCreateRequest> dependenciesToCreate;

  final List<int> assignmentIdsToDelete;
  final List<ResourceAssignmentUpdateAction> assignmentsToUpdate;
  final List<ResourceAssignmentCreateRequest> assignmentsToCreate;

  const TaskEditResult({
    required this.taskRequest,
    required this.parentId,
    this.dependencyIdsToDelete = const <int>[],
    this.dependenciesToUpdate = const <TaskDependencyUpdateAction>[],
    this.dependenciesToCreate = const <DependencyCreateRequest>[],
    this.assignmentIdsToDelete = const <int>[],
    this.assignmentsToUpdate = const <ResourceAssignmentUpdateAction>[],
    this.assignmentsToCreate = const <ResourceAssignmentCreateRequest>[],
  });

  int get dependencyChangeCount =>
      dependencyIdsToDelete.length +
      dependenciesToUpdate.length +
      dependenciesToCreate.length;

  int get assignmentChangeCount =>
      assignmentIdsToDelete.length +
      assignmentsToUpdate.length +
      assignmentsToCreate.length;
}

class TaskDependencyUpdateAction {
  final int dependencyId;
  final DependencyUpdateRequest request;

  const TaskDependencyUpdateAction({
    required this.dependencyId,
    required this.request,
  });
}

class ResourceAssignmentUpdateAction {
  final int assignmentId;
  final ResourceAssignmentUpdateRequest request;

  const ResourceAssignmentUpdateAction({
    required this.assignmentId,
    required this.request,
  });
}
