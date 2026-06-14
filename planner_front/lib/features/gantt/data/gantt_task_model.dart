class GanttTask {
  final int id;
  final String title;

  final DateTime startDate;
  final DateTime endDate;
  final int duration;

  final bool isDone;
  final bool isCritical;
  final int progressPercent;
  final int? totalFloat;

  final List<GanttResourceAssignment> resourceAssignments;

  GanttTask({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.isDone,
    required this.isCritical,
    required this.progressPercent,
    this.totalFloat,
    this.resourceAssignments = const [],
    
  });

  factory GanttTask.fromJson(Map<String, dynamic> json) {
    final assignmentsJson = json['resourceAssignments'];

    return GanttTask(
      id: json['id'],
      title: json['title'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      duration: json['duration'] ?? 0,
      isDone: json['isDone'] ?? false,
      isCritical: json['isCritical'] ?? false,
      progressPercent: json['progressPercent'] ?? 0,
      totalFloat: json['totalFloat'],
      resourceAssignments: assignmentsJson is List
          ? assignmentsJson
              .map(
                (item) => GanttResourceAssignment.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList()
          : [],
    );
  }

  String get assignmentSummary {
    if (resourceAssignments.isEmpty) {
      return 'Non assignée';
    }

    return resourceAssignments
        .map((assignment) => assignment.targetLabel)
        .join(', ');
  }

  String get assignmentTooltip {
    if (resourceAssignments.isEmpty) {
      return 'Assignation : aucune';
    }

    return resourceAssignments.map((assignment) {
      return '${assignment.targetLabel} · '
          '${assignment.workloadHours}h · '
          '${assignment.allocationPercent}%';
    }).join('\n');
  }
}

class GanttResourceAssignment {
  final int assignmentId;

  final int? resourceId;
  final String? resourceName;
  final String? resourceType;

  final int? resourceGroupId;
  final String? resourceGroupName;

  final double workloadHours;
  final int allocationPercent;
  final int progressPercent;

  GanttResourceAssignment({
    required this.assignmentId,
    this.resourceId,
    this.resourceName,
    this.resourceType,
    this.resourceGroupId,
    this.resourceGroupName,
    required this.workloadHours,
    required this.allocationPercent,
    required this.progressPercent,
  });

  factory GanttResourceAssignment.fromJson(Map<String, dynamic> json) {
    return GanttResourceAssignment(
      assignmentId: json['assignmentId'] ?? json['id'] ?? 0,
      resourceId: json['resourceId'],
      resourceName: json['resourceName'],
      resourceType: json['resourceType'],
      resourceGroupId: json['resourceGroupId'],
      resourceGroupName: json['resourceGroupName'],
      workloadHours: json['workloadHours'] != null
          ? (json['workloadHours'] as num).toDouble()
          : 0,
      allocationPercent: json['allocationPercent'] != null
          ? (json['allocationPercent'] as num).toInt()
          : 0,
      progressPercent: json['progressPercent'] != null
          ? (json['progressPercent'] as num).toInt()
          : 0,
    );
  }

  String get targetLabel {
    if (resourceGroupId != null) {
      return 'Groupe : ${resourceGroupName ?? 'Groupe #$resourceGroupId'}';
    }

    if (resourceId != null) {
      return resourceName ?? 'Ressource #$resourceId';
    }

    return 'Cible inconnue';
  }
}