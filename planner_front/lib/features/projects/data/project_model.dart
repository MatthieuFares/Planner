class Project {
  final int id;
  final String name;
  final String? description;

  Project({
    required this.id,
    required this.name,
    this.description,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'] ?? json['title'] ?? json['projectName'] ?? 'Projet sans nom',
      description: json['description'],
    );
  }
}

class ProjectCreateRequest {
  final String name;
  final String? description;

  ProjectCreateRequest({
    required this.name,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
    };
  }
}

class ProjectUpdateRequest {
  final String name;
  final String? description;

  ProjectUpdateRequest({
    required this.name,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
    };
  }
}