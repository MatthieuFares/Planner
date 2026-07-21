class ResourceAssignment {
  final int id;
  final int taskId;
  final String? taskTitle;

  final int? resourceId;
  final String? resourceName;

  final int? resourceGroupId;
  final String? resourceGroupName;

  final double workloadHours;
  final int allocationPercent;

  const ResourceAssignment({
    required this.id,
    required this.taskId,
    this.taskTitle,
    this.resourceId,
    this.resourceName,
    this.resourceGroupId,
    this.resourceGroupName,
    required this.workloadHours,
    required this.allocationPercent,
  });

  factory ResourceAssignment.fromJson(
    Map<String, dynamic> json,
  ) {
    return ResourceAssignment(
      id: _readInt(
        json['id'] ?? json['assignmentId'],
      ),
      taskId: _readInt(json['taskId']),
      taskTitle: _readNullableText(
        json['taskTitle'],
      ),
      resourceId: _readNullableInt(
        json['resourceId'],
      ),
      resourceName: _readNullableText(
        json['resourceName'],
      ),
      resourceGroupId: _readNullableInt(
        json['resourceGroupId'],
      ),
      resourceGroupName: _readNullableText(
        json['resourceGroupName'],
      ),
      workloadHours: _readDouble(
        json['workloadHours'],
      ),
      allocationPercent: _readInt(
        json['allocationPercent'],
      ),
    );
  }

  String get targetLabel {
    if (resourceGroupId != null) {
      return resourceGroupName ??
          'Groupe #$resourceGroupId';
    }

    if (resourceId != null) {
      return resourceName ?? 'Ressource #$resourceId';
    }

    return 'Cible inconnue';
  }

  bool get targetsGroup => resourceGroupId != null;

  bool get targetsResource => resourceId != null;

  bool get hasValidTarget =>
      targetsResource != targetsGroup;
}

class ResourceAssignmentCreateRequest {
  final int taskId;
  final int? resourceId;
  final int? resourceGroupId;
  final double workloadHours;
  final int allocationPercent;

  const ResourceAssignmentCreateRequest({
    required this.taskId,
    this.resourceId,
    this.resourceGroupId,
    required this.workloadHours,
    required this.allocationPercent,
  });

  Map<String, dynamic> toJson() {
    _validateTarget(
      resourceId: resourceId,
      resourceGroupId: resourceGroupId,
    );

    return {
      'taskId': taskId,
      'resourceId': resourceId,
      'resourceGroupId': resourceGroupId,
      'workloadHours': workloadHours,
      'allocationPercent': allocationPercent,
    };
  }
}

class ResourceAssignmentUpdateRequest {
  final int taskId;
  final int? resourceId;
  final int? resourceGroupId;
  final double workloadHours;
  final int allocationPercent;

  const ResourceAssignmentUpdateRequest({
    required this.taskId,
    this.resourceId,
    this.resourceGroupId,
    required this.workloadHours,
    required this.allocationPercent,
  });

  Map<String, dynamic> toJson() {
    _validateTarget(
      resourceId: resourceId,
      resourceGroupId: resourceGroupId,
    );

    return {
      'taskId': taskId,
      'resourceId': resourceId,
      'resourceGroupId': resourceGroupId,
      'workloadHours': workloadHours,
      'allocationPercent': allocationPercent,
    };
  }
}

void _validateTarget({
  required int? resourceId,
  required int? resourceGroupId,
}) {
  final hasResource = resourceId != null;
  final hasGroup = resourceGroupId != null;

  if (hasResource == hasGroup) {
    throw StateError(
      'Une assignation doit cibler exactement '
      'une ressource ou un groupe.',
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _readNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value.toString());
}

double _readDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();

  return double.tryParse(
        value?.toString().replaceAll(',', '.') ?? '',
      ) ??
      0;
}

String? _readNullableText(dynamic value) {
  if (value == null) return null;

  final text = value.toString().trim();

  return text.isEmpty ? null : text;
}
