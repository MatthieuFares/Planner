class StructuredGanttResponse {
  final int projectId;
  final String projectName;
  final String clientName;
  final String projectCode;
  final DateTime? projectStartDate;
  final DateTime? projectEndDate;
  final List<StructuredGanttItem> items;

  StructuredGanttResponse({
    required this.projectId,
    required this.projectName,
    required this.clientName,
    required this.projectCode,
    required this.projectStartDate,
    required this.projectEndDate,
    required this.items,
  });

  factory StructuredGanttResponse.fromJson(Map<String, dynamic> json) {
    return StructuredGanttResponse(
      projectId: json['projectId'],
      projectName: json['projectName'] ?? '',
      clientName: json['clientName'] ?? '',
      projectCode: json['projectCode'] ?? '',
      projectStartDate: json['projectStartDate'] != null
          ? DateTime.parse(json['projectStartDate'])
          : null,
      projectEndDate: json['projectEndDate'] != null
          ? DateTime.parse(json['projectEndDate'])
          : null,
      items: (json['items'] as List<dynamic>)
          .map((item) => StructuredGanttItem.fromJson(item))
          .toList(),
    );
  }
}

class StructuredGanttItem {
  final int id;
  final int projectId;
  final int? parentId;
  final String name;
  final String type;
  final int sortOrder;
  final String wbsCode;
  final int level;
  final int? taskId;
  final StructuredGanttTask? task;

  StructuredGanttItem({
    required this.id,
    required this.projectId,
    required this.parentId,
    required this.name,
    required this.type,
    required this.sortOrder,
    required this.wbsCode,
    required this.level,
    required this.taskId,
    required this.task,
  });

  factory StructuredGanttItem.fromJson(Map<String, dynamic> json) {
    return StructuredGanttItem(
      id: json['id'],
      projectId: json['projectId'],
      parentId: json['parentId'],
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      sortOrder: json['sortOrder'] ?? 0,
      wbsCode: json['wbsCode'] ?? '',
      level: json['level'] ?? 0,
      taskId: json['taskId'],
      task: json['task'] != null
          ? StructuredGanttTask.fromJson(json['task'])
          : null,
    );
  }
}

class StructuredGanttTask {
  final int id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final int duration;
  final bool isDone;
  final bool isCritical;
  final int progressPercent;
  final int? actualDuration;
  final int? assignedResourcesCount;
  final double? workloadHours;
  final DateTime? earlyStart;
  final DateTime? earlyFinish;
  final DateTime? lateStart;
  final DateTime? lateFinish;
  final int totalFloat;

  final DateTime? deadline;
  final int delayDays;
  final bool isLate;

  StructuredGanttTask({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.isDone,
    required this.isCritical,
    required this.progressPercent,
    required this.actualDuration,
    required this.assignedResourcesCount,
    required this.workloadHours,
    required this.earlyStart,
    required this.earlyFinish,
    required this.lateStart,
    required this.lateFinish,
    required this.totalFloat,
    required this.deadline,
    required this.delayDays,
    required this.isLate,
  });

  factory StructuredGanttTask.fromJson(Map<String, dynamic> json) {
    return StructuredGanttTask(
      id: json['id'],
      title: json['title'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      duration: json['duration'] ?? 0,
      isDone: json['isDone'] ?? false,
      isCritical: json['isCritical'] ?? false,
      progressPercent: json['progressPercent'] ?? 0,
      actualDuration: json['actualDuration'],
      assignedResourcesCount: json['assignedResourcesCount'],
      workloadHours: json['workloadHours'] != null
          ? (json['workloadHours'] as num).toDouble()
          : null,
      earlyStart: json['earlyStart'] != null
          ? DateTime.parse(json['earlyStart'])
          : null,
      earlyFinish: json['earlyFinish'] != null
          ? DateTime.parse(json['earlyFinish'])
          : null,
      lateStart: json['lateStart'] != null
          ? DateTime.parse(json['lateStart'])
          : null,
      lateFinish: json['lateFinish'] != null
          ? DateTime.parse(json['lateFinish'])
          : null,
      totalFloat: json['totalFloat'] ?? 0,

      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      delayDays: json['delayDays'] ?? 0,
      isLate: json['isLate'] ?? false,
    );
  }
}