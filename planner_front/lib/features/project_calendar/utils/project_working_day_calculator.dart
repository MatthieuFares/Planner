import '../data/project_calendar_exception_model.dart';
import '../data/project_calendar_model.dart';
import '../data/project_calendar_period_model.dart';

class ProjectWorkingDayCalculator {
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool isSameDay(DateTime first, DateTime second) {
    final cleanFirst = dateOnly(first);
    final cleanSecond = dateOnly(second);

    return cleanFirst == cleanSecond;
  }

  static ProjectCalendarExceptionModel? findException({
    required DateTime date,
    required List<ProjectCalendarExceptionModel> exceptions,
  }) {
    final cleanDate = dateOnly(date);

    for (final exception in exceptions) {
      if (isSameDay(exception.date, cleanDate)) {
        return exception;
      }
    }

    return null;
  }

  static ProjectCalendarPeriodModel? findPeriod({
    required DateTime date,
    required List<ProjectCalendarPeriodModel> periods,
  }) {
    final cleanDate = dateOnly(date);

    for (final period in periods) {
      final startDate = dateOnly(period.startDate);
      final endDate = dateOnly(period.endDate);

      if (!cleanDate.isBefore(startDate) &&
          !cleanDate.isAfter(endDate)) {
        return period;
      }
    }

    return null;
  }

  static bool isWorkingDay({
    required DateTime date,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
  }) {
    final cleanDate = dateOnly(date);

    final exception = findException(
      date: cleanDate,
      exceptions: exceptions,
    );

    if (exception != null) {
      return exception.isWorkingDay;
    }

    final period = findPeriod(
      date: cleanDate,
      periods: periods,
    );

    if (period != null) {
      return false;
    }

    switch (cleanDate.weekday) {
      case DateTime.monday:
        return calendar.workMonday;
      case DateTime.tuesday:
        return calendar.workTuesday;
      case DateTime.wednesday:
        return calendar.workWednesday;
      case DateTime.thursday:
        return calendar.workThursday;
      case DateTime.friday:
        return calendar.workFriday;
      case DateTime.saturday:
        return calendar.workSaturday;
      case DateTime.sunday:
        return calendar.workSunday;
      default:
        return false;
    }
  }

  static DateTime normalizeToWorkingDay({
    required DateTime date,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
    bool forward = true,
  }) {
    var currentDate = dateOnly(date);

    if (isWorkingDay(
      date: currentDate,
      calendar: calendar,
      exceptions: exceptions,
      periods: periods,
    )) {
      return currentDate;
    }

    for (var index = 0; index < 3660; index++) {
      currentDate = currentDate.add(
        Duration(days: forward ? 1 : -1),
      );

      if (isWorkingDay(
        date: currentDate,
        calendar: calendar,
        exceptions: exceptions,
        periods: periods,
      )) {
        return currentDate;
      }
    }

    throw StateError(
      'Impossible de trouver un jour ouvré dans le calendrier projet.',
    );
  }

  static DateTime addWorkingDays({
    required DateTime date,
    required int workingDays,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
  }) {
    if (workingDays < 0) {
      return subtractWorkingDays(
        date: date,
        workingDays: workingDays.abs(),
        calendar: calendar,
        exceptions: exceptions,
        periods: periods,
      );
    }

    var currentDate = normalizeToWorkingDay(
      date: date,
      calendar: calendar,
      exceptions: exceptions,
      periods: periods,
      forward: true,
    );

    if (workingDays == 0) {
      return currentDate;
    }

    var addedDays = 0;

    while (addedDays < workingDays) {
      currentDate = currentDate.add(const Duration(days: 1));

      if (isWorkingDay(
        date: currentDate,
        calendar: calendar,
        exceptions: exceptions,
        periods: periods,
      )) {
        addedDays++;
      }
    }

    return currentDate;
  }

  static DateTime subtractWorkingDays({
    required DateTime date,
    required int workingDays,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
  }) {
    if (workingDays < 0) {
      return addWorkingDays(
        date: date,
        workingDays: workingDays.abs(),
        calendar: calendar,
        exceptions: exceptions,
        periods: periods,
      );
    }

    var currentDate = normalizeToWorkingDay(
      date: date,
      calendar: calendar,
      exceptions: exceptions,
      periods: periods,
      forward: false,
    );

    if (workingDays == 0) {
      return currentDate;
    }

    var removedDays = 0;

    while (removedDays < workingDays) {
      currentDate = currentDate.subtract(const Duration(days: 1));

      if (isWorkingDay(
        date: currentDate,
        calendar: calendar,
        exceptions: exceptions,
        periods: periods,
      )) {
        removedDays++;
      }
    }

    return currentDate;
  }

  static DateTime calculateTaskEndDate({
    required DateTime startDate,
    required int duration,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
  }) {
    if (duration <= 0) {
      throw ArgumentError.value(
        duration,
        'duration',
        'La durée doit être supérieure à zéro.',
      );
    }

    final normalizedStartDate = normalizeToWorkingDay(
      date: startDate,
      calendar: calendar,
      exceptions: exceptions,
      periods: periods,
      forward: true,
    );

    return addWorkingDays(
      date: normalizedStartDate,
      workingDays: duration - 1,
      calendar: calendar,
      exceptions: exceptions,
      periods: periods,
    );
  }
}
