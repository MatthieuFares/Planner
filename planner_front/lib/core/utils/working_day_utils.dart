class WorkingDayUtils {
  static bool isWorkingDay(DateTime date) {
    return date.weekday != DateTime.saturday &&
        date.weekday != DateTime.sunday;
  }

  static DateTime addWorkingDays(DateTime startDate, int workingDays) {
    var date = DateTime(startDate.year, startDate.month, startDate.day);

    if (workingDays <= 0) {
      return _normalizeToWorkingDay(date);
    }

    var addedDays = 0;

    while (addedDays < workingDays) {
      date = date.add(const Duration(days: 1));

      if (isWorkingDay(date)) {
        addedDays++;
      }
    }

    return date;
  }

  static DateTime subtractWorkingDays(DateTime startDate, int workingDays) {
    var date = DateTime(startDate.year, startDate.month, startDate.day);

    if (workingDays <= 0) {
      return _normalizeToWorkingDay(date, forward: false);
    }

    var removedDays = 0;

    while (removedDays < workingDays) {
      date = date.subtract(const Duration(days: 1));

      if (isWorkingDay(date)) {
        removedDays++;
      }
    }

    return date;
  }

  static int countWorkingDays(DateTime startDate, DateTime endDate) {
    var start = DateTime(startDate.year, startDate.month, startDate.day);
    var end = DateTime(endDate.year, endDate.month, endDate.day);

    if (start == end) {
      return 0;
    }

    var count = 0;

    if (start.isBefore(end)) {
      var date = start;

      while (date.isBefore(end)) {
        date = date.add(const Duration(days: 1));

        if (isWorkingDay(date)) {
          count++;
        }
      }

      return count;
    }

    var date = start;

    while (date.isAfter(end)) {
      date = date.subtract(const Duration(days: 1));

      if (isWorkingDay(date)) {
        count--;
      }
    }

    return count;
  }

  static DateTime _normalizeToWorkingDay(
    DateTime date, {
    bool forward = true,
  }) {
    var normalizedDate = DateTime(date.year, date.month, date.day);

    while (!isWorkingDay(normalizedDate)) {
      normalizedDate = forward
          ? normalizedDate.add(const Duration(days: 1))
          : normalizedDate.subtract(const Duration(days: 1));
    }

    return normalizedDate;
  }
}