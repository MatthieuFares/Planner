class ProjectMemberModel {
  final int id;
  final int projectId;
  final String userId;
  final String email;
  final String? displayName;
  final String role;
  final bool isOwner;
  final DateTime createdAt;

  const ProjectMemberModel({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isOwner,
    required this.createdAt,
  });

  String get effectiveName {
    final name = displayName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return email;
  }

  factory ProjectMemberModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProjectMemberModel(
      id: _readInt(json['id']),
      projectId: _readInt(json['projectId']),
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: _readNullableString(
        json['displayName'],
      ),
      role: json['role']?.toString() ?? 'Viewer',
      isOwner: json['isOwner'] == true,
      createdAt: _readDateTime(json['createdAt']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _readNullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static DateTime _readDateTime(dynamic value) {
    if (value is DateTime) return value;

    return DateTime.tryParse(
          value?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        );
  }
}

class ProjectMemberCreateRequest {
  final String email;
  final String role;

  const ProjectMemberCreateRequest({
    required this.email,
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim(),
      'role': role,
    };
  }
}

class ProjectMemberUpdateRequest {
  final String role;

  const ProjectMemberUpdateRequest({
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
    };
  }
}
