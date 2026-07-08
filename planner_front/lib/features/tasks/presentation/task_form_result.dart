import '../data/task_model.dart';

class TaskFormResult {
  final TaskCreateRequest taskRequest;

  final int? predecessorTaskId;
  final String dependencyType;
  final int offsetDays;

  final int? resourceId;
  final double? workloadHours;
  final int allocationPercent;

  const TaskFormResult({
    required this.taskRequest,
    this.predecessorTaskId,
    this.dependencyType = 'FS',
    this.offsetDays = 0,
    this.resourceId,
    this.workloadHours,
    this.allocationPercent = 100,
  });

  bool get hasPredecessor => predecessorTaskId != null;

  bool get hasAssignment =>
      resourceId != null && workloadHours != null && workloadHours! > 0;
}