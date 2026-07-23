class PlanningVersionSummaryModel {
  final int id;
  final int projectId;
  final int versionNumber;
  final String name;
  final String? description;
  final String? createdBy;
  final DateTime createdAt;
  final int taskCount;
  final int itemCount;
  final int dependencyCount;
  final int assignmentCount;
  final bool hasCalendar;

  const PlanningVersionSummaryModel({
    required this.id,
    required this.projectId,
    required this.versionNumber,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.taskCount,
    required this.itemCount,
    required this.dependencyCount,
    required this.assignmentCount,
    required this.hasCalendar,
  });

  factory PlanningVersionSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionSummaryModel(
      id: _readInt(json['id']),
      projectId: _readInt(json['projectId']),
      versionNumber: _readInt(json['versionNumber']),
      name: _readString(json['name']),
      description: _readNullableString(json['description']),
      createdBy: _readNullableString(json['createdBy']),
      createdAt: _readDateTime(json['createdAt']),
      taskCount: _readInt(json['taskCount']),
      itemCount: _readInt(json['itemCount']),
      dependencyCount: _readInt(json['dependencyCount']),
      assignmentCount: _readInt(json['assignmentCount']),
      hasCalendar: _readBool(json['hasCalendar']),
    );
  }
}

class PlanningVersionDetailModel {
  final int id;
  final int projectId;
  final int versionNumber;
  final String name;
  final String? description;
  final String? createdBy;
  final DateTime createdAt;
  final List<PlanningVersionTaskModel> tasks;
  final List<PlanningVersionItemModel> items;
  final List<PlanningVersionDependencyModel> dependencies;
  final List<PlanningVersionAssignmentModel> assignments;
  final PlanningVersionCalendarModel? calendar;

  const PlanningVersionDetailModel({
    required this.id,
    required this.projectId,
    required this.versionNumber,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.tasks,
    required this.items,
    required this.dependencies,
    required this.assignments,
    required this.calendar,
  });

  factory PlanningVersionDetailModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionDetailModel(
      id: _readInt(json['id']),
      projectId: _readInt(json['projectId']),
      versionNumber: _readInt(json['versionNumber']),
      name: _readString(json['name']),
      description: _readNullableString(json['description']),
      createdBy: _readNullableString(json['createdBy']),
      createdAt: _readDateTime(json['createdAt']),
      tasks: _readList(json['tasks'])
          .map(
            (item) => PlanningVersionTaskModel.fromJson(
              _readMap(item),
            ),
          )
          .toList(),
      items: _readList(json['items'])
          .map(
            (item) => PlanningVersionItemModel.fromJson(
              _readMap(item),
            ),
          )
          .toList(),
      dependencies: _readList(json['dependencies'])
          .map(
            (item) => PlanningVersionDependencyModel.fromJson(
              _readMap(item),
            ),
          )
          .toList(),
      assignments: _readList(json['assignments'])
          .map(
            (item) => PlanningVersionAssignmentModel.fromJson(
              _readMap(item),
            ),
          )
          .toList(),
      calendar: json['calendar'] == null
          ? null
          : PlanningVersionCalendarModel.fromJson(
              _readMap(json['calendar']),
            ),
    );
  }
}

class PlanningVersionTaskModel {
  final int originalTaskId;
  final String title;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? duration;
  final int progressPercent;
  final bool isDone;
  final int? actualDuration;
  final int? assignedResourcesCount;
  final double? workloadHours;
  final DateTime? earlyStart;
  final DateTime? earlyFinish;
  final DateTime? lateStart;
  final DateTime? lateFinish;
  final int? totalFloat;
  final bool isCritical;
  final DateTime? deadline;
  final int delayDays;
  final bool isLate;

  const PlanningVersionTaskModel({
    required this.originalTaskId,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.progressPercent,
    required this.isDone,
    required this.actualDuration,
    required this.assignedResourcesCount,
    required this.workloadHours,
    required this.earlyStart,
    required this.earlyFinish,
    required this.lateStart,
    required this.lateFinish,
    required this.totalFloat,
    required this.isCritical,
    required this.deadline,
    required this.delayDays,
    required this.isLate,
  });

  factory PlanningVersionTaskModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionTaskModel(
      originalTaskId: _readInt(json['originalTaskId']),
      title: _readString(json['title']),
      description: _readNullableString(json['description']),
      startDate: _readNullableDateTime(json['startDate']),
      endDate: _readNullableDateTime(json['endDate']),
      duration: _readNullableInt(json['duration']),
      progressPercent: _readInt(json['progressPercent']),
      isDone: _readBool(json['isDone']),
      actualDuration: _readNullableInt(json['actualDuration']),
      assignedResourcesCount:
          _readNullableInt(json['assignedResourcesCount']),
      workloadHours: _readNullableDouble(json['workloadHours']),
      earlyStart: _readNullableDateTime(json['earlyStart']),
      earlyFinish: _readNullableDateTime(json['earlyFinish']),
      lateStart: _readNullableDateTime(json['lateStart']),
      lateFinish: _readNullableDateTime(json['lateFinish']),
      totalFloat: _readNullableInt(json['totalFloat']),
      isCritical: _readBool(json['isCritical']),
      deadline: _readNullableDateTime(json['deadline']),
      delayDays: _readInt(json['delayDays']),
      isLate: _readBool(json['isLate']),
    );
  }
}

class PlanningVersionItemModel {
  final int originalPlanningItemId;
  final int? originalParentId;
  final String name;
  final int type;
  final int sortOrder;
  final String wbsCode;
  final int? originalTaskId;

  const PlanningVersionItemModel({
    required this.originalPlanningItemId,
    required this.originalParentId,
    required this.name,
    required this.type,
    required this.sortOrder,
    required this.wbsCode,
    required this.originalTaskId,
  });

  factory PlanningVersionItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionItemModel(
      originalPlanningItemId:
          _readInt(json['originalPlanningItemId']),
      originalParentId: _readNullableInt(json['originalParentId']),
      name: _readString(json['name']),
      type: _readInt(json['type']),
      sortOrder: _readInt(json['sortOrder']),
      wbsCode: _readString(json['wbsCode']),
      originalTaskId: _readNullableInt(json['originalTaskId']),
    );
  }

  String get typeLabel {
    switch (type) {
      case 0:
        return 'Section';
      case 1:
        return 'Phase';
      case 2:
        return 'Zone';
      case 3:
        return 'Étage';
      case 4:
        return 'Lot';
      case 5:
        return 'Tâche';
      default:
        return 'Type $type';
    }
  }
}

class PlanningVersionDependencyModel {
  final int originalDependencyId;
  final int originalPredecessorTaskId;
  final int originalSuccessorTaskId;
  final String type;
  final int offsetDays;

  const PlanningVersionDependencyModel({
    required this.originalDependencyId,
    required this.originalPredecessorTaskId,
    required this.originalSuccessorTaskId,
    required this.type,
    required this.offsetDays,
  });

  factory PlanningVersionDependencyModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionDependencyModel(
      originalDependencyId:
          _readInt(json['originalDependencyId']),
      originalPredecessorTaskId:
          _readInt(json['originalPredecessorTaskId']),
      originalSuccessorTaskId:
          _readInt(json['originalSuccessorTaskId']),
      type: _readString(json['type']),
      offsetDays: _readInt(json['offsetDays']),
    );
  }
}

class PlanningVersionAssignmentModel {
  final int originalAssignmentId;
  final int originalTaskId;
  final int? originalResourceId;
  final String? resourceName;
  final int? originalResourceGroupId;
  final String? resourceGroupName;
  final double workloadHours;
  final int allocationPercent;

  const PlanningVersionAssignmentModel({
    required this.originalAssignmentId,
    required this.originalTaskId,
    required this.originalResourceId,
    required this.resourceName,
    required this.originalResourceGroupId,
    required this.resourceGroupName,
    required this.workloadHours,
    required this.allocationPercent,
  });

  factory PlanningVersionAssignmentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionAssignmentModel(
      originalAssignmentId:
          _readInt(json['originalAssignmentId']),
      originalTaskId: _readInt(json['originalTaskId']),
      originalResourceId:
          _readNullableInt(json['originalResourceId']),
      resourceName: _readNullableString(json['resourceName']),
      originalResourceGroupId:
          _readNullableInt(json['originalResourceGroupId']),
      resourceGroupName:
          _readNullableString(json['resourceGroupName']),
      workloadHours: _readDouble(json['workloadHours']),
      allocationPercent: _readInt(json['allocationPercent']),
    );
  }

  String get targetName =>
      resourceName ?? resourceGroupName ?? 'Cible supprimée';
}

class PlanningVersionCalendarModel {
  final bool workMonday;
  final bool workTuesday;
  final bool workWednesday;
  final bool workThursday;
  final bool workFriday;
  final bool workSaturday;
  final bool workSunday;
  final List<PlanningVersionCalendarExceptionModel> exceptions;
  final List<PlanningVersionCalendarPeriodModel> periods;

  const PlanningVersionCalendarModel({
    required this.workMonday,
    required this.workTuesday,
    required this.workWednesday,
    required this.workThursday,
    required this.workFriday,
    required this.workSaturday,
    required this.workSunday,
    required this.exceptions,
    required this.periods,
  });

  factory PlanningVersionCalendarModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionCalendarModel(
      workMonday: _readBool(json['workMonday']),
      workTuesday: _readBool(json['workTuesday']),
      workWednesday: _readBool(json['workWednesday']),
      workThursday: _readBool(json['workThursday']),
      workFriday: _readBool(json['workFriday']),
      workSaturday: _readBool(json['workSaturday']),
      workSunday: _readBool(json['workSunday']),
      exceptions: _readList(json['exceptions'])
          .map(
            (item) => PlanningVersionCalendarExceptionModel.fromJson(
              _readMap(item),
            ),
          )
          .toList(),
      periods: _readList(json['periods'])
          .map(
            (item) => PlanningVersionCalendarPeriodModel.fromJson(
              _readMap(item),
            ),
          )
          .toList(),
    );
  }
}

class PlanningVersionCalendarExceptionModel {
  final DateTime date;
  final String label;
  final bool isWorkingDay;

  const PlanningVersionCalendarExceptionModel({
    required this.date,
    required this.label,
    required this.isWorkingDay,
  });

  factory PlanningVersionCalendarExceptionModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionCalendarExceptionModel(
      date: _readDateTime(json['date']),
      label: _readString(json['label']),
      isWorkingDay: _readBool(json['isWorkingDay']),
    );
  }
}

class PlanningVersionCalendarPeriodModel {
  final DateTime startDate;
  final DateTime endDate;
  final String label;

  const PlanningVersionCalendarPeriodModel({
    required this.startDate,
    required this.endDate,
    required this.label,
  });

  factory PlanningVersionCalendarPeriodModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionCalendarPeriodModel(
      startDate: _readDateTime(json['startDate']),
      endDate: _readDateTime(json['endDate']),
      label: _readString(json['label']),
    );
  }
}

class PlanningVersionComparisonModel {
  final int versionId;
  final int projectId;
  final int versionNumber;
  final String versionName;
  final DateTime versionCreatedAt;
  final DateTime comparedAt;
  final PlanningVersionComparisonSummaryModel summary;
  final List<PlanningVersionTaskComparisonModel> tasks;
  final bool structureChanged;
  final bool dependenciesChanged;
  final bool assignmentsChanged;
  final bool calendarChanged;

  const PlanningVersionComparisonModel({
    required this.versionId,
    required this.projectId,
    required this.versionNumber,
    required this.versionName,
    required this.versionCreatedAt,
    required this.comparedAt,
    required this.summary,
    required this.tasks,
    required this.structureChanged,
    required this.dependenciesChanged,
    required this.assignmentsChanged,
    required this.calendarChanged,
  });

  factory PlanningVersionComparisonModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionComparisonModel(
      versionId: _readInt(json['versionId']),
      projectId: _readInt(json['projectId']),
      versionNumber: _readInt(json['versionNumber']),
      versionName: _readString(json['versionName']),
      versionCreatedAt: _readDateTime(json['versionCreatedAt']),
      comparedAt: _readDateTime(json['comparedAt']),
      summary: PlanningVersionComparisonSummaryModel.fromJson(
        _readMap(json['summary']),
      ),
      tasks: _readList(json['tasks'])
          .map(
            (item) => PlanningVersionTaskComparisonModel.fromJson(
              _readMap(item),
            ),
          )
          .toList(),
      structureChanged: _readBool(json['structureChanged']),
      dependenciesChanged: _readBool(json['dependenciesChanged']),
      assignmentsChanged: _readBool(json['assignmentsChanged']),
      calendarChanged: _readBool(json['calendarChanged']),
    );
  }

  bool get hasChanges =>
      summary.changedTaskCount > 0 ||
      structureChanged ||
      dependenciesChanged ||
      assignmentsChanged ||
      calendarChanged;
}

class PlanningVersionComparisonSummaryModel {
  final int versionTaskCount;
  final int currentTaskCount;
  final int addedTaskCount;
  final int removedTaskCount;
  final int modifiedTaskCount;
  final int unchangedTaskCount;
  final int changedTaskCount;

  const PlanningVersionComparisonSummaryModel({
    required this.versionTaskCount,
    required this.currentTaskCount,
    required this.addedTaskCount,
    required this.removedTaskCount,
    required this.modifiedTaskCount,
    required this.unchangedTaskCount,
    required this.changedTaskCount,
  });

  factory PlanningVersionComparisonSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionComparisonSummaryModel(
      versionTaskCount: _readInt(json['versionTaskCount']),
      currentTaskCount: _readInt(json['currentTaskCount']),
      addedTaskCount: _readInt(json['addedTaskCount']),
      removedTaskCount: _readInt(json['removedTaskCount']),
      modifiedTaskCount: _readInt(json['modifiedTaskCount']),
      unchangedTaskCount: _readInt(json['unchangedTaskCount']),
      changedTaskCount: _readInt(json['changedTaskCount']),
    );
  }
}

class PlanningVersionTaskComparisonModel {
  final int taskId;
  final String status;
  final String title;
  final List<String> changedFields;
  final PlanningVersionTaskStateModel? versionState;
  final PlanningVersionTaskStateModel? currentState;

  const PlanningVersionTaskComparisonModel({
    required this.taskId,
    required this.status,
    required this.title,
    required this.changedFields,
    required this.versionState,
    required this.currentState,
  });

  factory PlanningVersionTaskComparisonModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionTaskComparisonModel(
      taskId: _readInt(json['taskId']),
      status: _readString(json['status']),
      title: _readString(json['title']),
      changedFields: _readList(json['changedFields'])
          .map((item) => item.toString())
          .toList(),
      versionState: json['versionState'] == null
          ? null
          : PlanningVersionTaskStateModel.fromJson(
              _readMap(json['versionState']),
            ),
      currentState: json['currentState'] == null
          ? null
          : PlanningVersionTaskStateModel.fromJson(
              _readMap(json['currentState']),
            ),
    );
  }

  bool get isAdded => status == 'Added';
  bool get isRemoved => status == 'Removed';
  bool get isModified => status == 'Modified';
  bool get isUnchanged => status == 'Unchanged';
}

class PlanningVersionTaskStateModel {
  final int taskId;
  final String title;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? duration;
  final int progressPercent;
  final bool isDone;
  final int? actualDuration;
  final int? assignedResourcesCount;
  final double? workloadHours;
  final DateTime? earlyStart;
  final DateTime? earlyFinish;
  final DateTime? lateStart;
  final DateTime? lateFinish;
  final int? totalFloat;
  final bool isCritical;
  final DateTime? deadline;
  final int delayDays;
  final bool isLate;

  const PlanningVersionTaskStateModel({
    required this.taskId,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.progressPercent,
    required this.isDone,
    required this.actualDuration,
    required this.assignedResourcesCount,
    required this.workloadHours,
    required this.earlyStart,
    required this.earlyFinish,
    required this.lateStart,
    required this.lateFinish,
    required this.totalFloat,
    required this.isCritical,
    required this.deadline,
    required this.delayDays,
    required this.isLate,
  });

  factory PlanningVersionTaskStateModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionTaskStateModel(
      taskId: _readInt(json['taskId']),
      title: _readString(json['title']),
      description: _readNullableString(json['description']),
      startDate: _readNullableDateTime(json['startDate']),
      endDate: _readNullableDateTime(json['endDate']),
      duration: _readNullableInt(json['duration']),
      progressPercent: _readInt(json['progressPercent']),
      isDone: _readBool(json['isDone']),
      actualDuration: _readNullableInt(json['actualDuration']),
      assignedResourcesCount:
          _readNullableInt(json['assignedResourcesCount']),
      workloadHours: _readNullableDouble(json['workloadHours']),
      earlyStart: _readNullableDateTime(json['earlyStart']),
      earlyFinish: _readNullableDateTime(json['earlyFinish']),
      lateStart: _readNullableDateTime(json['lateStart']),
      lateFinish: _readNullableDateTime(json['lateFinish']),
      totalFloat: _readNullableInt(json['totalFloat']),
      isCritical: _readBool(json['isCritical']),
      deadline: _readNullableDateTime(json['deadline']),
      delayDays: _readInt(json['delayDays']),
      isLate: _readBool(json['isLate']),
    );
  }
}

class RestorePlanningVersionResponseModel {
  final int versionId;
  final int projectId;
  final int versionNumber;
  final String versionName;
  final DateTime restoredAt;
  final String? restoredBy;
  final int? safetyVersionId;
  final int updatedTaskCount;
  final int createdTaskCount;
  final int deletedTaskCount;
  final int restoredItemCount;
  final int restoredDependencyCount;
  final int restoredAssignmentCount;
  final bool calendarRestored;
  final List<PlanningVersionTaskMappingModel> taskMappings;
  final List<String> warnings;

  const RestorePlanningVersionResponseModel({
    required this.versionId,
    required this.projectId,
    required this.versionNumber,
    required this.versionName,
    required this.restoredAt,
    required this.restoredBy,
    required this.safetyVersionId,
    required this.updatedTaskCount,
    required this.createdTaskCount,
    required this.deletedTaskCount,
    required this.restoredItemCount,
    required this.restoredDependencyCount,
    required this.restoredAssignmentCount,
    required this.calendarRestored,
    required this.taskMappings,
    required this.warnings,
  });

  factory RestorePlanningVersionResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return RestorePlanningVersionResponseModel(
      versionId: _readInt(json['versionId']),
      projectId: _readInt(json['projectId']),
      versionNumber: _readInt(json['versionNumber']),
      versionName: _readString(json['versionName']),
      restoredAt: _readDateTime(json['restoredAt']),
      restoredBy: _readNullableString(json['restoredBy']),
      safetyVersionId: _readNullableInt(json['safetyVersionId']),
      updatedTaskCount: _readInt(json['updatedTaskCount']),
      createdTaskCount: _readInt(json['createdTaskCount']),
      deletedTaskCount: _readInt(json['deletedTaskCount']),
      restoredItemCount: _readInt(json['restoredItemCount']),
      restoredDependencyCount:
          _readInt(json['restoredDependencyCount']),
      restoredAssignmentCount:
          _readInt(json['restoredAssignmentCount']),
      calendarRestored: _readBool(json['calendarRestored']),
      taskMappings: _readList(json['taskMappings'])
          .map(
            (item) => PlanningVersionTaskMappingModel.fromJson(
              _readMap(item),
            ),
          )
          .toList(),
      warnings: _readList(json['warnings'])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class PlanningVersionTaskMappingModel {
  final int originalTaskId;
  final int restoredTaskId;
  final bool reusedExistingId;

  const PlanningVersionTaskMappingModel({
    required this.originalTaskId,
    required this.restoredTaskId,
    required this.reusedExistingId,
  });

  factory PlanningVersionTaskMappingModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlanningVersionTaskMappingModel(
      originalTaskId: _readInt(json['originalTaskId']),
      restoredTaskId: _readInt(json['restoredTaskId']),
      reusedExistingId: _readBool(json['reusedExistingId']),
    );
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }

  return <String, dynamic>{};
}

List<dynamic> _readList(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }

  if (value is List) {
    return value.cast<dynamic>();
  }

  return const <dynamic>[];
}

String _readString(dynamic value) {
  return value?.toString() ?? '';
}

String? _readNullableString(dynamic value) {
  final text = value?.toString().trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _readNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}

double _readDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _readNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString());
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  return value?.toString().toLowerCase() == 'true';
}

DateTime _readDateTime(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _readNullableDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}
