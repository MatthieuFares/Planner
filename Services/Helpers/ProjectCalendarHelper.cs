using PlannerAPI.Models;

namespace PlannerAPI.Services.Helpers
{
    public static class ProjectCalendarHelper
    {
        public static bool IsWorkingDay(DateTime date, ProjectCalendar calendar)
        {
            var normalizedDate = date.Date;

            var exception = calendar.Exceptions
                .FirstOrDefault(e => e.Date.Date == normalizedDate);

            if (exception != null)
                return exception.IsWorkingDay;

            return normalizedDate.DayOfWeek switch
            {
                DayOfWeek.Monday => calendar.WorkMonday,
                DayOfWeek.Tuesday => calendar.WorkTuesday,
                DayOfWeek.Wednesday => calendar.WorkWednesday,
                DayOfWeek.Thursday => calendar.WorkThursday,
                DayOfWeek.Friday => calendar.WorkFriday,
                DayOfWeek.Saturday => calendar.WorkSaturday,
                DayOfWeek.Sunday => calendar.WorkSunday,
                _ => false
            };
        }

        public static DateTime AddWorkingDays(DateTime startDate, int workingDays, ProjectCalendar calendar)
        {
            var date = startDate.Date;

            if (workingDays <= 0)
                return NormalizeToWorkingDay(date, calendar, forward: true);

            var addedDays = 0;

            while (addedDays < workingDays)
            {
                date = date.AddDays(1);

                if (IsWorkingDay(date, calendar))
                    addedDays++;
            }

            return date;
        }

        public static DateTime SubtractWorkingDays(DateTime startDate, int workingDays, ProjectCalendar calendar)
        {
            var date = startDate.Date;

            if (workingDays <= 0)
                return NormalizeToWorkingDay(date, calendar, forward: false);

            var removedDays = 0;

            while (removedDays < workingDays)
            {
                date = date.AddDays(-1);

                if (IsWorkingDay(date, calendar))
                    removedDays++;
            }

            return date;
        }

        public static int CountWorkingDays(DateTime startDate, DateTime endDate, ProjectCalendar calendar)
        {
            var start = startDate.Date;
            var end = endDate.Date;

            if (start == end)
                return 0;

            var count = 0;

            if (start < end)
            {
                var date = start;

                while (date < end)
                {
                    date = date.AddDays(1);

                    if (IsWorkingDay(date, calendar))
                        count++;
                }

                return count;
            }
            else
            {
                var date = start;

                while (date > end)
                {
                    date = date.AddDays(-1);

                    if (IsWorkingDay(date, calendar))
                        count--;
                }

                return count;
            }
        }

        public static DateTime NormalizeToWorkingDay(DateTime date, ProjectCalendar calendar, bool forward = true)
        {
            var normalizedDate = date.Date;

            if (IsWorkingDay(normalizedDate, calendar))
                return normalizedDate;

            while (!IsWorkingDay(normalizedDate, calendar))
            {
                normalizedDate = normalizedDate.AddDays(forward ? 1 : -1);
            }

            return normalizedDate;
        }
    }
}