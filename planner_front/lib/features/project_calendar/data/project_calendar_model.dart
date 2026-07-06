class ProjectCalendarModel {
  final int id;
  final int projectId;

  final bool workMonday;
  final bool workTuesday;
  final bool workWednesday;
  final bool workThursday;
  final bool workFriday;
  final bool workSaturday;
  final bool workSunday;

  const ProjectCalendarModel({
    required this.id,
    required this.projectId,
    required this.workMonday,
    required this.workTuesday,
    required this.workWednesday,
    required this.workThursday,
    required this.workFriday,
    required this.workSaturday,
    required this.workSunday,
  });

  factory ProjectCalendarModel.fromJson(Map<String, dynamic> json) {
    return ProjectCalendarModel(
      id: json['id'] as int,
      projectId: json['projectId'] as int,
      workMonday: json['workMonday'] as bool,
      workTuesday: json['workTuesday'] as bool,
      workWednesday: json['workWednesday'] as bool,
      workThursday: json['workThursday'] as bool,
      workFriday: json['workFriday'] as bool,
      workSaturday: json['workSaturday'] as bool,
      workSunday: json['workSunday'] as bool,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'workMonday': workMonday,
      'workTuesday': workTuesday,
      'workWednesday': workWednesday,
      'workThursday': workThursday,
      'workFriday': workFriday,
      'workSaturday': workSaturday,
      'workSunday': workSunday,
    };
  }

  ProjectCalendarModel copyWith({
    bool? workMonday,
    bool? workTuesday,
    bool? workWednesday,
    bool? workThursday,
    bool? workFriday,
    bool? workSaturday,
    bool? workSunday,
  }) {
    return ProjectCalendarModel(
      id: id,
      projectId: projectId,
      workMonday: workMonday ?? this.workMonday,
      workTuesday: workTuesday ?? this.workTuesday,
      workWednesday: workWednesday ?? this.workWednesday,
      workThursday: workThursday ?? this.workThursday,
      workFriday: workFriday ?? this.workFriday,
      workSaturday: workSaturday ?? this.workSaturday,
      workSunday: workSunday ?? this.workSunday,
    );
  }
}