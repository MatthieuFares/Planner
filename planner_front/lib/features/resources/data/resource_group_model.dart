class ResourceGroup {
  final int id;
  final String name;
  final String? description;
  final List<ResourceGroupMember> members;

  ResourceGroup({
    required this.id,
    required this.name,
    this.description,
    this.members = const [],
  });

  factory ResourceGroup.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'];

    return ResourceGroup(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      members: membersJson is List
          ? membersJson
              .map((item) => ResourceGroupMember.fromJson(
                    item as Map<String, dynamic>,
                  ))
              .toList()
          : [],
    );
  }
}

class ResourceGroupMember {
  final int id;
  final int resourceGroupId;
  final int resourceId;
  final String resourceName;
  final String resourceType;
  final double capacityHoursPerWeek;
  final double costPerHour;

  ResourceGroupMember({
    required this.id,
    required this.resourceGroupId,
    required this.resourceId,
    required this.resourceName,
    required this.resourceType,
    required this.capacityHoursPerWeek,
    required this.costPerHour,
  });

  factory ResourceGroupMember.fromJson(Map<String, dynamic> json) {
    return ResourceGroupMember(
      id: json['id'],
      resourceGroupId: json['resourceGroupId'],
      resourceId: json['resourceId'],
      resourceName: json['resourceName'] ?? '',
      resourceType: json['resourceType'] ?? '',
      capacityHoursPerWeek: json['capacityHoursPerWeek'] != null
          ? (json['capacityHoursPerWeek'] as num).toDouble()
          : 0,
      costPerHour: json['costPerHour'] != null
          ? (json['costPerHour'] as num).toDouble()
          : 0,
    );
  }
}

class ResourceGroupCreateRequest {
  final String name;
  final String? description;

  ResourceGroupCreateRequest({
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

class ResourceGroupUpdateRequest {
  final String name;
  final String? description;

  ResourceGroupUpdateRequest({
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

class ResourceGroupMemberRequest {
  final int resourceGroupId;
  final int resourceId;

  ResourceGroupMemberRequest({
    required this.resourceGroupId,
    required this.resourceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'resourceGroupId': resourceGroupId,
      'resourceId': resourceId,
    };
  }
}