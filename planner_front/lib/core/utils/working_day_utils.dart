class WorkingDayUtils {
  static bool isWorkingDay(DateTime date) {
    return date.weekday != DateTime.saturday &&
        date.weekday != DateTime.sunday;
  }

  /// Ajoute un nombre de jours ouvrés après la date de départ.
  ///
  /// Exemple :
  /// lundi + 1 jour ouvré = mardi.
  ///
  /// Cette méthode convient aux offsets et aux déplacements de dates.
  static DateTime addWorkingDays(
    DateTime startDate,
    int workingDays,
  ) {
    var date = _dateOnly(startDate);

    if (workingDays < 0) {
      return subtractWorkingDays(
        date,
        workingDays.abs(),
      );
    }

    if (workingDays == 0) {
      return normalizeToWorkingDay(
        date,
        forward: true,
      );
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

  /// Calcule la date de fin inclusive d'une tâche.
  ///
  /// Exemples :
  /// - lundi, durée 1 jour => lundi ;
  /// - lundi, durée 5 jours => vendredi ;
  /// - vendredi, durée 2 jours => lundi suivant.
  static DateTime calculateTaskEndDate(
    DateTime startDate,
    int duration,
  ) {
    if (duration <= 0) {
      throw ArgumentError.value(
        duration,
        'duration',
        'La durée doit être supérieure à zéro.',
      );
    }

    final normalizedStart = normalizeToWorkingDay(
      startDate,
      forward: true,
    );

    return addWorkingDays(
      normalizedStart,
      duration - 1,
    );
  }

  /// Calcule la date de début inclusive à partir d'une date de fin.
  ///
  /// Exemple :
  /// vendredi, durée 5 jours => lundi.
  static DateTime calculateTaskStartDate(
    DateTime endDate,
    int duration,
  ) {
    if (duration <= 0) {
      throw ArgumentError.value(
        duration,
        'duration',
        'La durée doit être supérieure à zéro.',
      );
    }

    final normalizedEnd = normalizeToWorkingDay(
      endDate,
      forward: false,
    );

    return subtractWorkingDays(
      normalizedEnd,
      duration - 1,
    );
  }

  static DateTime subtractWorkingDays(
    DateTime startDate,
    int workingDays,
  ) {
    var date = _dateOnly(startDate);

    if (workingDays < 0) {
      return addWorkingDays(
        date,
        workingDays.abs(),
      );
    }

    if (workingDays == 0) {
      return normalizeToWorkingDay(
        date,
        forward: false,
      );
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

  static int countWorkingDays(
    DateTime startDate,
    DateTime endDate,
  ) {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);

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

  static DateTime normalizeToWorkingDay(
    DateTime date, {
    bool forward = true,
  }) {
    var normalizedDate = _dateOnly(date);

    while (!isWorkingDay(normalizedDate)) {
      normalizedDate = forward
          ? normalizedDate.add(const Duration(days: 1))
          : normalizedDate.subtract(const Duration(days: 1));
    }

    return normalizedDate;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }
}