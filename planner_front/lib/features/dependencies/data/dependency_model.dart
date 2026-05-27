class TaskDependency {
  final int id;
  final int predecessorId;
  final int successorId;
  final String type;
  final int offsetDays;

  TaskDependency({
    required this.id,
    required this.predecessorId,
    required this.successorId,
    required this.type,
    required this.offsetDays,
  });

  factory TaskDependency.fromJson(Map<String, dynamic> json) {
    return TaskDependency(
      id: json['id'],
      predecessorId: json['predecessorId'],
      successorId: json['successorId'],
      type: json['type'] ?? 'FS',
      offsetDays: json['offsetDays'] ?? 0,
    );
  }
}

class DependencyCreateRequest {
  final int predecessorId;
  final int successorId;
  final String type;
  final int offsetDays;

  DependencyCreateRequest({
    required this.predecessorId,
    required this.successorId,
    required this.type,
    required this.offsetDays,
  });

  Map<String, dynamic> toJson() {
    return {
      'predecessorId': predecessorId,
      'successorId': successorId,
      'type': type,
      'offsetDays': offsetDays,
    };
  }
}

class DependencyUpdateRequest {
  final int predecessorId;
  final int successorId;
  final String type;
  final int offsetDays;

  DependencyUpdateRequest({
    required this.predecessorId,
    required this.successorId,
    required this.type,
    required this.offsetDays,
  });

  Map<String, dynamic> toJson() {
    return {
      'predecessorId': predecessorId,
      'successorId': successorId,
      'type': type,
      'offsetDays': offsetDays,
    };
  }
}