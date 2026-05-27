class PlannerTask {
  final int id;
  final String title;
  final String? description;
  final bool isDone;
  final int projectId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? duration;
  final double? workloadHours;
  final int? actualDuration;
  final int? assignedResourcesCount;
  final bool? isCritical;
  final int? floatValue;

  PlannerTask({
    required this.id,
    required this.title,
    this.description,
    required this.isDone,
    required this.projectId,
    this.startDate,
    this.endDate,
    this.duration,
    this.workloadHours,
    this.actualDuration,
    this.assignedResourcesCount,
    this.isCritical,
    this.floatValue,
  });

  factory PlannerTask.fromJson(Map<String, dynamic> json) {
    return PlannerTask(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      isDone: json['isDone'] ?? false,
      projectId: json['projectId'],
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'])
          : null,
      duration: json['duration'],
      workloadHours: json['workloadHours'] != null
          ? (json['workloadHours'] as num).toDouble()
          : null,
      actualDuration: json['actualDuration'],
      assignedResourcesCount: json['assignedResourcesCount'],
      isCritical: json['isCritical'],
      floatValue: json['float'] ?? json['floatValue'],
    );
  }
}

class TaskCreateRequest {
  final String title;
  final String? description;
  final int projectId;
  final DateTime startDate;
  final DateTime endDate;
  final int duration;
  final bool isDone;

  TaskCreateRequest({
    required this.title,
    this.description,
    required this.projectId,
    required this.startDate,
    required this.endDate,
    required this.duration,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'projectId': projectId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'duration': duration,
      'isDone': isDone,
    };
  }
}

class TaskUpdateRequest {
  final String title;
  final String? description;
  final int projectId;
  final DateTime startDate;
  final DateTime endDate;
  final int duration;
  final bool isDone;

  TaskUpdateRequest({
    required this.title,
    this.description,
    required this.projectId,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.isDone,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'projectId': projectId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'duration': duration,
      'isDone': isDone,
    };
  }
}