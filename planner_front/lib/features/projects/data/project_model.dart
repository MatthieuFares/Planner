class Project {
  final int id;
  final String name;
  final String? description;
  final String? clientName;
  final String? projectCode;
  final DateTime? startDate;
  final DateTime? endDate;

  Project({
    required this.id,
    required this.name,
    this.description,
    this.clientName,
    this.projectCode,
    this.startDate,
    this.endDate,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'] ??
          json['title'] ??
          json['projectName'] ??
          'Projet sans nom',
      description: json['description'],
      clientName: json['clientName'],
      projectCode: json['projectCode'],
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'])
          : null,
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

  ProjectCreateRequest({
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

  ProjectUpdateRequest({
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