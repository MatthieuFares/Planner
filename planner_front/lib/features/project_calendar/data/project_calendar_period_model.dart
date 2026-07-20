class ProjectCalendarPeriodModel {
  final int id;
  final int projectCalendarId;
  final DateTime startDate;
  final DateTime endDate;
  final String label;

  const ProjectCalendarPeriodModel({
    required this.id,
    required this.projectCalendarId,
    required this.startDate,
    required this.endDate,
    required this.label,
  });

  factory ProjectCalendarPeriodModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProjectCalendarPeriodModel(
      id: json['id'] as int,
      projectCalendarId: json['projectCalendarId'] as int,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      label: (json['label'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'label': label,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'label': label,
    };
  }

  ProjectCalendarPeriodModel copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? label,
  }) {
    return ProjectCalendarPeriodModel(
      id: id,
      projectCalendarId: projectCalendarId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      label: label ?? this.label,
    );
  }
}
