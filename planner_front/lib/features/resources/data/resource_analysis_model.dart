class ProjectResourceAnalysis {
  final int projectId;
  final double totalWorkloadHours;
  final double estimatedCost;
  final List<ResourceWorkload> resources;

  ProjectResourceAnalysis({
    required this.projectId,
    required this.totalWorkloadHours,
    required this.estimatedCost,
    required this.resources,
  });

  factory ProjectResourceAnalysis.fromJson(Map<String, dynamic> json) {
    final rawResources = json['resources'];

    return ProjectResourceAnalysis(
      projectId: json['projectId'] != null
          ? (json['projectId'] as num).toInt()
          : 0,
      totalWorkloadHours: json['totalWorkloadHours'] != null
          ? (json['totalWorkloadHours'] as num).toDouble()
          : 0,
      estimatedCost: json['estimatedCost'] != null
          ? (json['estimatedCost'] as num).toDouble()
          : 0,
      resources: rawResources is List
          ? rawResources
              .map(
                (json) => ResourceWorkload.fromJson(
                  json as Map<String, dynamic>,
                ),
              )
              .toList()
          : [],
    );
  }

  int get overloadedResourceCount {
    return resources.where((resource) => resource.isOverloaded).length;
  }
}

class ResourceWorkload {
  final int resourceId;
  final String resourceName;
  final String resourceType;

  final double assignedHours;
  final int? capacityHoursPerWeek;

  final double? costPerHour;
  final double estimatedCost;

  final double? utilizationPercent;
  final bool isOverloaded;

  ResourceWorkload({
    required this.resourceId,
    required this.resourceName,
    required this.resourceType,
    required this.assignedHours,
    required this.capacityHoursPerWeek,
    required this.costPerHour,
    required this.estimatedCost,
    required this.utilizationPercent,
    required this.isOverloaded,
  });

  factory ResourceWorkload.fromJson(Map<String, dynamic> json) {
    return ResourceWorkload(
      resourceId: json['resourceId'] != null
          ? (json['resourceId'] as num).toInt()
          : 0,
      resourceName: json['resourceName'] ?? '',
      resourceType: json['resourceType'] ?? '',
      assignedHours: json['assignedHours'] != null
          ? (json['assignedHours'] as num).toDouble()
          : 0,
      capacityHoursPerWeek: json['capacityHoursPerWeek'] != null
          ? (json['capacityHoursPerWeek'] as num).toInt()
          : null,
      costPerHour: json['costPerHour'] != null
          ? (json['costPerHour'] as num).toDouble()
          : null,
      estimatedCost: json['estimatedCost'] != null
          ? (json['estimatedCost'] as num).toDouble()
          : 0,
      utilizationPercent: json['utilizationPercent'] != null
          ? (json['utilizationPercent'] as num).toDouble()
          : null,
      isOverloaded: json['isOverloaded'] == true,
    );
  }
}