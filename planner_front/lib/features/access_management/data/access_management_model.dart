class AccessManagementOverview {
  final bool isGlobalAdmin;
  final bool canManageAccess;
  final bool canManageGlobalPermissions;
  final List<AccessManagementProject> projects;
  final List<AccessManagementUser> users;

  const AccessManagementOverview({
    required this.isGlobalAdmin,
    required this.canManageAccess,
    required this.canManageGlobalPermissions,
    required this.projects,
    required this.users,
  });

  factory AccessManagementOverview.fromJson(
    Map<String, dynamic> json,
  ) {
    return AccessManagementOverview(
      isGlobalAdmin:
          json['isGlobalAdmin'] == true,
      canManageAccess:
          json['canManageAccess'] == true,
      canManageGlobalPermissions:
          json['canManageGlobalPermissions'] == true,
      projects: _readMaps(json['projects'])
          .map(AccessManagementProject.fromJson)
          .toList(),
      users: _readMaps(json['users'])
          .map(AccessManagementUser.fromJson)
          .toList(),
    );
  }
}

class AccessManagementProject {
  final int id;
  final String name;
  final String? clientName;
  final bool isOwner;
  final int memberCount;

  const AccessManagementProject({
    required this.id,
    required this.name,
    required this.clientName,
    required this.isOwner,
    required this.memberCount,
  });

  factory AccessManagementProject.fromJson(
    Map<String, dynamic> json,
  ) {
    return AccessManagementProject(
      id: _readInt(json['id']),
      name: json['name']?.toString() ??
          'Projet sans nom',
      clientName:
          _readNullableString(json['clientName']),
      isOwner: json['isOwner'] == true,
      memberCount:
          _readInt(json['memberCount']),
    );
  }
}

class AccessManagementUser {
  final String userId;
  final String email;
  final String? displayName;
  final bool isActive;
  final bool canCreateProjects;
  final bool canCreateProjectsEffectively;
  final bool canManageResources;
  final bool isGlobalAdmin;
  final List<AccessManagementMembership> memberships;

  const AccessManagementUser({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.isActive,
    required this.canCreateProjects,
    required this.canCreateProjectsEffectively,
    required this.canManageResources,
    required this.isGlobalAdmin,
    required this.memberships,
  });

  String get effectiveName {
    final name = displayName?.trim();

    return name == null || name.isEmpty
        ? email
        : name;
  }

  factory AccessManagementUser.fromJson(
    Map<String, dynamic> json,
  ) {
    return AccessManagementUser(
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName:
          _readNullableString(json['displayName']),
      isActive: json['isActive'] == true,
      canCreateProjects:
          json['canCreateProjects'] == true,
      canCreateProjectsEffectively:
          json['canCreateProjectsEffectively'] == true,
      canManageResources:
          json['canManageResources'] == true,
      isGlobalAdmin:
          json['isGlobalAdmin'] == true,
      memberships:
          _readMaps(json['memberships'])
              .map(
                AccessManagementMembership.fromJson,
              )
              .toList(),
    );
  }
}

class AccessManagementMembership {
  final int memberId;
  final int projectId;
  final String projectName;
  final String role;
  final bool isOwner;
  final DateTime createdAt;

  const AccessManagementMembership({
    required this.memberId,
    required this.projectId,
    required this.projectName,
    required this.role,
    required this.isOwner,
    required this.createdAt,
  });

  factory AccessManagementMembership.fromJson(
    Map<String, dynamic> json,
  ) {
    return AccessManagementMembership(
      memberId: _readInt(json['memberId']),
      projectId: _readInt(json['projectId']),
      projectName:
          json['projectName']?.toString() ??
              'Projet',
      role:
          json['role']?.toString() ?? 'Viewer',
      isOwner: json['isOwner'] == true,
      createdAt:
          DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          ),
    );
  }
}

class GlobalUserPermissionsUpdateRequest {
  final bool isActive;
  final bool canCreateProjects;
  final bool canManageResources;
  final bool isGlobalAdmin;

  const GlobalUserPermissionsUpdateRequest({
    required this.isActive,
    required this.canCreateProjects,
    required this.canManageResources,
    required this.isGlobalAdmin,
  });

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'canCreateProjects': canCreateProjects,
      'canManageResources': canManageResources,
      'isGlobalAdmin': isGlobalAdmin,
    };
  }
}

List<Map<String, dynamic>> _readMaps(
  dynamic value,
) {
  final values =
      value is List ? value : const <dynamic>[];

  return values
      .whereType<Map>()
      .map(
        (item) =>
            Map<String, dynamic>.from(item),
      )
      .toList();
}

int _readInt(dynamic value) {
  if (value is int) return value;

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _readNullableString(dynamic value) {
  final text = value?.toString().trim();

  return text == null || text.isEmpty
      ? null
      : text;
}
