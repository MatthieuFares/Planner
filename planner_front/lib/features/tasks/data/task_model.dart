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
  final int progressPercent;

  final DateTime? deadline;
  final bool isLate;
  final int? delayDays;

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
    this.progressPercent = 0,
    this.deadline,
    this.isLate = false,
    this.delayDays,
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
      floatValue: json['totalFloat'] ?? json['float'] ?? json['floatValue'],
      progressPercent: json['progressPercent'] ?? 0,
      deadline:
          json['deadline'] != null ? DateTime.tryParse(json['deadline']) : null,
      isLate: json['isLate'] ?? false,
      delayDays: json['delayDays'],
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
  final int progressPercent;
  final DateTime? deadline;

  TaskCreateRequest({
    required this.title,
    this.description,
    required this.projectId,
    required this.startDate,
    required this.endDate,
    required this.duration,
    this.isDone = false,
    this.progressPercent = 0,
    this.deadline,
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
      'progressPercent': progressPercent,
      'deadline': deadline?.toIso8601String(),
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
  final int progressPercent;
  final DateTime? deadline;

  TaskUpdateRequest({
    required this.title,
    this.description,
    required this.projectId,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.isDone,
    this.progressPercent = 0,
    this.deadline,
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
      'progressPercent': progressPercent,
      'deadline': deadline?.toIso8601String(),
    };
  }
}