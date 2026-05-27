class ResourceAssignment {
  final int id;
  final int taskId;

  final int? resourceId;
  final String? resourceName;

  final int? resourceGroupId;
  final String? resourceGroupName;

  final double workloadHours;
  final int allocationPercent;

  ResourceAssignment({
    required this.id,
    required this.taskId,
    this.resourceId,
    this.resourceName,
    this.resourceGroupId,
    this.resourceGroupName,
    required this.workloadHours,
    required this.allocationPercent,
  });

  factory ResourceAssignment.fromJson(Map<String, dynamic> json) {
    return ResourceAssignment(
      id: json['id'] ?? json['assignmentId'],
      taskId: json['taskId'],

      resourceId: json['resourceId'],
      resourceName: json['resourceName'],

      resourceGroupId: json['resourceGroupId'],
      resourceGroupName: json['resourceGroupName'],

      workloadHours: json['workloadHours'] != null
          ? (json['workloadHours'] as num).toDouble()
          : 0,
      allocationPercent: json['allocationPercent'] != null
          ? (json['allocationPercent'] as num).toInt()
          : 0,
    );
  }

  String get targetLabel {
    if (resourceGroupId != null) {
      return resourceGroupName ?? 'Groupe #$resourceGroupId';
    }

    if (resourceId != null) {
      return resourceName ?? 'Ressource #$resourceId';
    }

    return 'Cible inconnue';
  }

  bool get targetsGroup => resourceGroupId != null;
}

class ResourceAssignmentCreateRequest {
  final int taskId;
  final int? resourceId;
  final int? resourceGroupId;
  final double workloadHours;
  final int allocationPercent;

  ResourceAssignmentCreateRequest({
    required this.taskId,
    this.resourceId,
    this.resourceGroupId,
    required this.workloadHours,
    required this.allocationPercent,
  });

  Map<String, dynamic> toJson() {
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

  ResourceAssignmentUpdateRequest({
    required this.taskId,
    this.resourceId,
    this.resourceGroupId,
    required this.workloadHours,
    required this.allocationPercent,
  });

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'resourceId': resourceId,
      'resourceGroupId': resourceGroupId,
      'workloadHours': workloadHours,
      'allocationPercent': allocationPercent,
    };
  }
}