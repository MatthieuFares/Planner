class ProjectBaselineModel {
  final int id;
  final int projectId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final bool isActive;
  final int taskCount;

  const ProjectBaselineModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.isActive,
    required this.taskCount,
  });

  factory ProjectBaselineModel.fromJson(Map<String, dynamic> json) {
    return ProjectBaselineModel(
      id: json['id'] as int,
      projectId: json['projectId'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool? ?? false,
      taskCount: json['taskCount'] as int? ?? 0,
    );
  }
}

class ProjectBaselineTaskModel {
  final int id;
  final int projectBaselineId;
  final int taskId;
  final String taskTitle;
  final String? wbsCode;
  final DateTime? startDate;
  final DateTime? endDate;
  final int duration;
  final int progressPercent;
  final DateTime? deadline;
  final int totalFloat;
  final bool isCritical;
  final bool isLate;
  final int delayDays;

  const ProjectBaselineTaskModel({
    required this.id,
    required this.projectBaselineId,
    required this.taskId,
    required this.taskTitle,
    required this.wbsCode,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.progressPercent,
    required this.deadline,
    required this.totalFloat,
    required this.isCritical,
    required this.isLate,
    required this.delayDays,
  });

  factory ProjectBaselineTaskModel.fromJson(Map<String, dynamic> json) {
    return ProjectBaselineTaskModel(
      id: json['id'] as int,
      projectBaselineId: json['projectBaselineId'] as int,
      taskId: json['taskId'] as int,
      taskTitle: json['taskTitle'] as String? ?? '',
      wbsCode: json['wbsCode'] as String?,
      startDate: _parseNullableDate(json['startDate']),
      endDate: _parseNullableDate(json['endDate']),
      duration: json['duration'] as int? ?? 0,
      progressPercent: json['progressPercent'] as int? ?? 0,
      deadline: _parseNullableDate(json['deadline']),
      totalFloat: json['totalFloat'] as int? ?? 0,
      isCritical: json['isCritical'] as bool? ?? false,
      isLate: json['isLate'] as bool? ?? false,
      delayDays: json['delayDays'] as int? ?? 0,
    );
  }
}

class ProjectBaselineDetailModel {
  final int id;
  final int projectId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final bool isActive;
  final List<ProjectBaselineTaskModel> tasks;

  const ProjectBaselineDetailModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.isActive,
    required this.tasks,
  });

  factory ProjectBaselineDetailModel.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'] as List<dynamic>? ?? [];

    return ProjectBaselineDetailModel(
      id: json['id'] as int,
      projectId: json['projectId'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool? ?? false,
      tasks: rawTasks
          .map(
            (item) => ProjectBaselineTaskModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class ProjectBaselineComparisonModel {
  final int baselineId;
  final int projectId;
  final String baselineName;
  final DateTime createdAt;
  final bool isActive;
  final List<ProjectBaselineComparisonRowModel> rows;

  const ProjectBaselineComparisonModel({
    required this.baselineId,
    required this.projectId,
    required this.baselineName,
    required this.createdAt,
    required this.isActive,
    required this.rows,
  });

  factory ProjectBaselineComparisonModel.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'] as List<dynamic>? ?? [];

    return ProjectBaselineComparisonModel(
      baselineId: json['baselineId'] as int,
      projectId: json['projectId'] as int,
      baselineName: json['baselineName'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool? ?? false,
      rows: rawRows
          .map(
            (item) => ProjectBaselineComparisonRowModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class ProjectBaselineComparisonRowModel {
  final int taskId;
  final String taskTitle;
  final String? wbsCode;

  final DateTime? baselineStartDate;
  final DateTime? currentStartDate;
  final int? startVarianceDays;

  final DateTime? baselineEndDate;
  final DateTime? currentEndDate;
  final int? endVarianceDays;

  final int baselineDuration;
  final int currentDuration;
  final int durationVarianceDays;

  final int baselineProgressPercent;
  final int currentProgressPercent;
  final int progressVariancePercent;

  final DateTime? baselineDeadline;
  final DateTime? currentDeadline;

  final int baselineTotalFloat;
  final int currentTotalFloat;
  final int totalFloatVariance;

  final bool baselineIsCritical;
  final bool currentIsCritical;

  final bool baselineIsLate;
  final bool currentIsLate;

  final int baselineDelayDays;
  final int currentDelayDays;

  final bool isDelayedComparedToBaseline;
  final bool isMissingFromCurrentPlanning;

  const ProjectBaselineComparisonRowModel({
    required this.taskId,
    required this.taskTitle,
    required this.wbsCode,
    required this.baselineStartDate,
    required this.currentStartDate,
    required this.startVarianceDays,
    required this.baselineEndDate,
    required this.currentEndDate,
    required this.endVarianceDays,
    required this.baselineDuration,
    required this.currentDuration,
    required this.durationVarianceDays,
    required this.baselineProgressPercent,
    required this.currentProgressPercent,
    required this.progressVariancePercent,
    required this.baselineDeadline,
    required this.currentDeadline,
    required this.baselineTotalFloat,
    required this.currentTotalFloat,
    required this.totalFloatVariance,
    required this.baselineIsCritical,
    required this.currentIsCritical,
    required this.baselineIsLate,
    required this.currentIsLate,
    required this.baselineDelayDays,
    required this.currentDelayDays,
    required this.isDelayedComparedToBaseline,
    required this.isMissingFromCurrentPlanning,
  });

  factory ProjectBaselineComparisonRowModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProjectBaselineComparisonRowModel(
      taskId: json['taskId'] as int,
      taskTitle: json['taskTitle'] as String? ?? '',
      wbsCode: json['wbsCode'] as String?,
      baselineStartDate: _parseNullableDate(json['baselineStartDate']),
      currentStartDate: _parseNullableDate(json['currentStartDate']),
      startVarianceDays: json['startVarianceDays'] as int?,
      baselineEndDate: _parseNullableDate(json['baselineEndDate']),
      currentEndDate: _parseNullableDate(json['currentEndDate']),
      endVarianceDays: json['endVarianceDays'] as int?,
      baselineDuration: json['baselineDuration'] as int? ?? 0,
      currentDuration: json['currentDuration'] as int? ?? 0,
      durationVarianceDays: json['durationVarianceDays'] as int? ?? 0,
      baselineProgressPercent: json['baselineProgressPercent'] as int? ?? 0,
      currentProgressPercent: json['currentProgressPercent'] as int? ?? 0,
      progressVariancePercent: json['progressVariancePercent'] as int? ?? 0,
      baselineDeadline: _parseNullableDate(json['baselineDeadline']),
      currentDeadline: _parseNullableDate(json['currentDeadline']),
      baselineTotalFloat: json['baselineTotalFloat'] as int? ?? 0,
      currentTotalFloat: json['currentTotalFloat'] as int? ?? 0,
      totalFloatVariance: json['totalFloatVariance'] as int? ?? 0,
      baselineIsCritical: json['baselineIsCritical'] as bool? ?? false,
      currentIsCritical: json['currentIsCritical'] as bool? ?? false,
      baselineIsLate: json['baselineIsLate'] as bool? ?? false,
      currentIsLate: json['currentIsLate'] as bool? ?? false,
      baselineDelayDays: json['baselineDelayDays'] as int? ?? 0,
      currentDelayDays: json['currentDelayDays'] as int? ?? 0,
      isDelayedComparedToBaseline:
          json['isDelayedComparedToBaseline'] as bool? ?? false,
      isMissingFromCurrentPlanning:
          json['isMissingFromCurrentPlanning'] as bool? ?? false,
    );
  }
}

DateTime? _parseNullableDate(dynamic value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) return null;

  return DateTime.parse(value);
}