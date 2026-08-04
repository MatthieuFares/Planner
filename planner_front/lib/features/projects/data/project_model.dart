class Project {
  final int id;
  final String name;
  final String? description;
  final String? clientName;
  final String? projectCode;
  final DateTime? startDate;
  final DateTime? endDate;

  final bool canEditPlanning;
  final bool canManageMembers;
  final bool canDeleteProject;

  const Project({
    required this.id,
    required this.name,
    this.description,
    this.clientName,
    this.projectCode,
    this.startDate,
    this.endDate,
    this.canEditPlanning = false,
    this.canManageMembers = false,
    this.canDeleteProject = false,
  });

  factory Project.fromJson(
    Map<String, dynamic> json,
  ) {
    return Project(
      id: _readInt(json['id']),
      name: json['name']?.toString() ??
          json['title']?.toString() ??
          json['projectName']?.toString() ??
          'Projet sans nom',
      description:
          _readNullableString(json['description']),
      clientName:
          _readNullableString(json['clientName']),
      projectCode:
          _readNullableString(json['projectCode']),
      startDate: _readDate(json['startDate']),
      endDate: _readDate(json['endDate']),
      canEditPlanning:
          json['canEditPlanning'] == true,
      canManageMembers:
          json['canManageMembers'] == true,
      canDeleteProject:
          json['canDeleteProject'] == true,
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static String? _readNullableString(
    dynamic value,
  ) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());
  }
}

class ProjectListResult {
  final bool canCreateProjects;
  final bool canImportProjects;
  final bool canManageAccess;
  final bool isGlobalAdmin;
  final List<Project> projects;

  const ProjectListResult({
    required this.canCreateProjects,
    required this.canImportProjects,
    required this.canManageAccess,
    required this.isGlobalAdmin,
    required this.projects,
  });

  factory ProjectListResult.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawProjects =
        json['projects'] as List<dynamic>? ??
            const <dynamic>[];

    return ProjectListResult(
      canCreateProjects:
          json['canCreateProjects'] == true,
      canImportProjects:
          json['canImportProjects'] == true,
      canManageAccess:
          json['canManageAccess'] == true,
      isGlobalAdmin:
          json['isGlobalAdmin'] == true,
      projects: rawProjects
          .whereType<Map>()
          .map(
            (item) => Project.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

class ProjectCreateRequest {
  final String name;
  final String? description;
  final String? clientName;
  final String? projectCode;
  final DateTime? startDate;
  final DateTime? endDate;

  const ProjectCreateRequest({
    required this.name,
    this.description,
    this.clientName,
    this.projectCode,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'clientName': clientName,
      'projectCode': projectCode,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }
}

class ProjectUpdateRequest {
  final String name;
  final String? description;
  final String? clientName;
  final String? projectCode;
  final DateTime? startDate;
  final DateTime? endDate;

  const ProjectUpdateRequest({
    required this.name,
    this.description,
    this.clientName,
    this.projectCode,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'clientName': clientName,
      'projectCode': projectCode,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }
}
