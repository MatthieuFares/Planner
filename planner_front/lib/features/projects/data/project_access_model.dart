class ProjectAccessModel {
  final int projectId;
  final bool canReadProject;
  final bool canEditPlanning;
  final bool canManageMembers;
  final bool canDeleteProject;
  final bool canCreateProjects;
  final bool canReadResourceCatalog;
  final bool canManageResourceCatalog;
  final bool canImportProjects;

  const ProjectAccessModel({
    required this.projectId,
    required this.canReadProject,
    required this.canEditPlanning,
    required this.canManageMembers,
    required this.canDeleteProject,
    required this.canCreateProjects,
    required this.canReadResourceCatalog,
    required this.canManageResourceCatalog,
    required this.canImportProjects,
  });

  factory ProjectAccessModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProjectAccessModel(
      projectId: _parseInt(json['projectId']),
      canReadProject:
          json['canReadProject'] == true,
      canEditPlanning:
          json['canEditPlanning'] == true,
      canManageMembers:
          json['canManageMembers'] == true,
      canDeleteProject:
          json['canDeleteProject'] == true,
      canCreateProjects:
          json['canCreateProjects'] == true,
      canReadResourceCatalog:
          json['canReadResourceCatalog'] == true,
      canManageResourceCatalog:
          json['canManageResourceCatalog'] == true,
      canImportProjects:
          json['canImportProjects'] == true,
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '') ?? 0;
}
