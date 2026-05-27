class Resource {
  final int id;
  final String name;
  final String type;
  final int capacityHoursPerWeek;
  final double costPerHour;

  Resource({
    required this.id,
    required this.name,
    required this.type,
    required this.capacityHoursPerWeek,
    required this.costPerHour,
  });

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      id: json['id'],
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      capacityHoursPerWeek: json['capacityHoursPerWeek'] != null
          ? (json['capacityHoursPerWeek'] as num).toInt()
          : 0,
      costPerHour: json['costPerHour'] != null
          ? (json['costPerHour'] as num).toDouble()
          : 0,
    );
  }
}

class ResourceCreateRequest {
  final String name;
  final String type;
  final int capacityHoursPerWeek;
  final double costPerHour;

  ResourceCreateRequest({
    required this.name,
    required this.type,
    required this.capacityHoursPerWeek,
    required this.costPerHour,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'capacityHoursPerWeek': capacityHoursPerWeek,
      'costPerHour': costPerHour,
    };
  }
}

class ResourceUpdateRequest {
  final String name;
  final String type;
  final int capacityHoursPerWeek;
  final double costPerHour;

  ResourceUpdateRequest({
    required this.name,
    required this.type,
    required this.capacityHoursPerWeek,
    required this.costPerHour,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'capacityHoursPerWeek': capacityHoursPerWeek,
      'costPerHour': costPerHour,
    };
  }
}