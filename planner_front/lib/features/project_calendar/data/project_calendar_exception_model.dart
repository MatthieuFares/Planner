class ProjectCalendarExceptionModel {
  final int id;
  final int projectCalendarId;
  final DateTime date;
  final String label;
  final bool isWorkingDay;

  const ProjectCalendarExceptionModel({
    required this.id,
    required this.projectCalendarId,
    required this.date,
    required this.label,
    required this.isWorkingDay,
  });

  factory ProjectCalendarExceptionModel.fromJson(Map<String, dynamic> json) {
    return ProjectCalendarExceptionModel(
      id: json['id'] as int,
      projectCalendarId: json['projectCalendarId'] as int,
      date: DateTime.parse(json['date'] as String),
      label: json['label'] as String? ?? '',
      isWorkingDay: json['isWorkingDay'] as bool,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'label': label,
      'isWorkingDay': isWorkingDay,
    };
  }
}