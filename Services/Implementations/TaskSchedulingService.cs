using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class TaskSchedulingService : ITaskSchedulingService
    {
        private readonly AppDbContext _context;

        public TaskSchedulingService(AppDbContext context)
        {
            _context = context;
        }

        private bool IsWorkingDay(DateTime date, ProjectCalendar calendar)
        {
            var normalizedDate = date.Date;

            var exception = calendar.Exceptions?
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

        private DateTime NormalizeToWorkingDay(DateTime date, ProjectCalendar calendar, bool forward = true)
        {
            var currentDate = date.Date;

            if (IsWorkingDay(currentDate, calendar))
                return currentDate;

            // Sécurité anti-boucle infinie si aucun jour ouvré n'est défini dans le calendrier.
            for (var i = 0; i < 366; i++)
            {
                currentDate = currentDate.AddDays(forward ? 1 : -1);

                if (IsWorkingDay(currentDate, calendar))
                    return currentDate;
            }

            throw new InvalidOperationException(
                "Impossible de trouver un jour ouvré dans le calendrier projet. " +
                "Vérifie qu'au moins un jour de la semaine est ouvré ou qu'une exception ouvrée existe."
            );
        }

        private DateTime AddWorkingDays(DateTime date, int days, ProjectCalendar calendar)
        {
            if (days < 0)
                return SubtractWorkingDays(date, Math.Abs(days), calendar);

            if (days == 0)
                return NormalizeToWorkingDay(date, calendar, forward: true);

            var currentDate = date.Date;
            var remainingDays = days;

            while (remainingDays > 0)
            {
                currentDate = currentDate.AddDays(1);

                if (IsWorkingDay(currentDate, calendar))
                    remainingDays--;
            }

            return currentDate;
        }

        private DateTime SubtractWorkingDays(DateTime date, int days, ProjectCalendar calendar)
        {
            if (days < 0)
                return AddWorkingDays(date, Math.Abs(days), calendar);

            if (days == 0)
                return NormalizeToWorkingDay(date, calendar, forward: false);

            var currentDate = date.Date;
            var remainingDays = days;

            while (remainingDays > 0)
            {
                currentDate = currentDate.AddDays(-1);

                if (IsWorkingDay(currentDate, calendar))
                    remainingDays--;
            }

            return currentDate;
        }

        private DateTime ApplyWorkingDayOffset(DateTime date, int offsetDays, ProjectCalendar calendar)
        {
            if (offsetDays > 0)
                return AddWorkingDays(date, offsetDays, calendar);

            if (offsetDays < 0)
                return SubtractWorkingDays(date, Math.Abs(offsetDays), calendar);

            return NormalizeToWorkingDay(date, calendar, forward: true);
        }

        private int CountWorkingDays(DateTime startDate, DateTime endDate, ProjectCalendar calendar)
        {
            var start = startDate.Date;
            var end = endDate.Date;

            if (start == end)
                return 0;

            var count = 0;

            if (start < end)
            {
                var currentDate = start;

                while (currentDate < end)
                {
                    currentDate = currentDate.AddDays(1);

                    if (IsWorkingDay(currentDate, calendar))
                        count++;
                }

                return count;
            }
            else
            {
                var currentDate = start;

                while (currentDate > end)
                {
                    currentDate = currentDate.AddDays(-1);

                    if (IsWorkingDay(currentDate, calendar))
                        count--;
                }

                return count;
            }
        }

        public async Task RecalculateTaskDatesAsync(int taskId)
        {
            var initialTask = await _context.Tasks
                .AsNoTracking()
                .FirstOrDefaultAsync(t => t.Id == taskId);

            if (initialTask == null)
                return;

            var calendar = await GetOrCreateProjectCalendarForSchedulingAsync(initialTask.ProjectId);

            await RecalculateTaskDatesInternalAsync(taskId, new HashSet<int>(), calendar);

            await CalculateCriticalPathAsync(initialTask.ProjectId);
        }

        private async Task RecalculateTaskDatesInternalAsync(
            int taskId,
            HashSet<int> visited,
            ProjectCalendar calendar)
        {
            if (!visited.Add(taskId))
                return;

            var task = await _context.Tasks
                .Include(t => t.Predecessors)
                    .ThenInclude(d => d.Predecessor)
                .Include(t => t.Successors)
                    .ThenInclude(d => d.Successor)
                .FirstOrDefaultAsync(t => t.Id == taskId);

            if (task == null)
                return;

            DateTime? latestStartConstraint = null;
            DateTime? latestEndConstraint = null;

            foreach (var dependency in task.Predecessors)
            {
                var predecessor = dependency.Predecessor;
                if (predecessor == null)
                    continue;

                switch (dependency.Type)
                {
                    case "FS":
                        if (predecessor.EndDate.HasValue)
                        {
                            latestStartConstraint = MaxDate(
                                latestStartConstraint,
                                ApplyWorkingDayOffset(
                                    predecessor.EndDate.Value,
                                    dependency.OffsetDays,
                                    calendar
                                )
                            );
                        }
                        break;

                    case "SS":
                        if (predecessor.StartDate.HasValue)
                        {
                            latestStartConstraint = MaxDate(
                                latestStartConstraint,
                                ApplyWorkingDayOffset(
                                    predecessor.StartDate.Value,
                                    dependency.OffsetDays,
                                    calendar
                                )
                            );
                        }
                        break;

                    case "FF":
                        if (predecessor.EndDate.HasValue)
                        {
                            latestEndConstraint = MaxDate(
                                latestEndConstraint,
                                ApplyWorkingDayOffset(
                                    predecessor.EndDate.Value,
                                    dependency.OffsetDays,
                                    calendar
                                )
                            );
                        }
                        break;

                    case "SF":
                        if (predecessor.StartDate.HasValue)
                        {
                            latestEndConstraint = MaxDate(
                                latestEndConstraint,
                                ApplyWorkingDayOffset(
                                    predecessor.StartDate.Value,
                                    dependency.OffsetDays,
                                    calendar
                                )
                            );
                        }
                        break;
                }
            }

            ApplySchedulingRules(task, latestStartConstraint, latestEndConstraint, calendar);

            await _context.SaveChangesAsync();

            var successorIds = task.Successors
                .Select(s => s.SuccessorId)
                .Distinct()
                .ToList();

            foreach (var successorId in successorIds)
            {
                await RecalculateTaskDatesInternalAsync(successorId, visited, calendar);
            }
        }

        private void ApplySchedulingRules(
            PlannerTask task,
            DateTime? latestStartConstraint,
            DateTime? latestEndConstraint,
            ProjectCalendar calendar)
        {
            if (!task.Duration.HasValue)
                return;

            var duration = task.Duration.Value;

            if (latestStartConstraint.HasValue && latestEndConstraint.HasValue)
            {
                var startConstraint = NormalizeToWorkingDay(
                    latestStartConstraint.Value,
                    calendar,
                    forward: true
                );

                var endConstraint = NormalizeToWorkingDay(
                    latestEndConstraint.Value,
                    calendar,
                    forward: false
                );

                var expectedEnd = AddWorkingDays(startConstraint, duration, calendar);

                if (expectedEnd > endConstraint)
                {
                    throw new InvalidOperationException(
                        $"Conflit de planification pour la tâche {task.Id} : " +
                        "les contraintes de début et de fin sont incompatibles avec la durée."
                    );
                }

                task.StartDate = startConstraint;
                task.EndDate = AddWorkingDays(task.StartDate.Value, duration, calendar);
                return;
            }

            if (latestStartConstraint.HasValue)
            {
                task.StartDate = NormalizeToWorkingDay(
                    latestStartConstraint.Value,
                    calendar,
                    forward: true
                );

                task.EndDate = AddWorkingDays(task.StartDate.Value, duration, calendar);
                return;
            }

            if (latestEndConstraint.HasValue)
            {
                task.EndDate = NormalizeToWorkingDay(
                    latestEndConstraint.Value,
                    calendar,
                    forward: false
                );

                task.StartDate = SubtractWorkingDays(task.EndDate.Value, duration, calendar);
                return;
            }

            if (task.StartDate.HasValue)
            {
                task.StartDate = NormalizeToWorkingDay(
                    task.StartDate.Value,
                    calendar,
                    forward: true
                );

                task.EndDate = AddWorkingDays(task.StartDate.Value, duration, calendar);
            }
            else if (task.EndDate.HasValue)
            {
                task.EndDate = NormalizeToWorkingDay(
                    task.EndDate.Value,
                    calendar,
                    forward: false
                );

                task.StartDate = SubtractWorkingDays(task.EndDate.Value, duration, calendar);
            }
        }

        private static DateTime MaxDate(DateTime? current, DateTime candidate)
        {
            return !current.HasValue || candidate > current.Value
                ? candidate
                : current.Value;
        }

        private DateTime? MinDate(DateTime? current, DateTime candidate)
        {
            if (!current.HasValue || candidate < current.Value)
                return candidate;

            return current;
        }

        public async Task CalculateCriticalPathAsync(int projectId)
        {
            var tasks = await _context.Tasks
                .Where(t => t.ProjectId == projectId)
                .Include(t => t.Predecessors)
                    .ThenInclude(d => d.Predecessor)
                .Include(t => t.Successors)
                    .ThenInclude(d => d.Successor)
                .ToListAsync();

            if (!tasks.Any())
                return;

            var calendar = await GetOrCreateProjectCalendarForSchedulingAsync(projectId);

            foreach (var task in tasks)
            {
                task.EarlyStart = task.StartDate;
                task.EarlyFinish = task.EndDate;
                task.LateStart = null;
                task.LateFinish = null;
                task.TotalFloat = null;
                task.IsCritical = false;
            }

            var projectEndDate = tasks
                .Where(t => t.EarlyFinish.HasValue)
                .Max(t => t.EarlyFinish);

            if (!projectEndDate.HasValue)
            {
                await _context.SaveChangesAsync();
                return;
            }

            var endTasks = tasks
                .Where(t => !t.Successors.Any())
                .ToList();

            foreach (var task in endTasks)
            {
                task.LateFinish = NormalizeToWorkingDay(
                    projectEndDate.Value,
                    calendar,
                    forward: false
                );

                if (task.Duration.HasValue)
                {
                    task.LateStart = SubtractWorkingDays(
                        task.LateFinish.Value,
                        task.Duration.Value,
                        calendar
                    );
                }
            }

            var orderedTasks = tasks
                .Where(t => t.EndDate.HasValue)
                .OrderByDescending(t => t.EndDate)
                .ToList();

            foreach (var task in orderedTasks)
            {
                if (!task.Successors.Any())
                    continue;

                DateTime? candidateLateStart = null;
                DateTime? candidateLateFinish = null;

                foreach (var dependency in task.Successors)
                {
                    var successor = dependency.Successor;

                    if (successor == null)
                        continue;

                    switch (dependency.Type)
                    {
                        case "FS":
                            if (successor.LateStart.HasValue)
                            {
                                var candidate = ApplyWorkingDayOffset(
                                    successor.LateStart.Value,
                                    -dependency.OffsetDays,
                                    calendar
                                );

                                candidateLateFinish = MinDate(candidateLateFinish, candidate);
                            }
                            break;

                        case "SS":
                            if (successor.LateStart.HasValue)
                            {
                                var candidate = ApplyWorkingDayOffset(
                                    successor.LateStart.Value,
                                    -dependency.OffsetDays,
                                    calendar
                                );

                                candidateLateStart = MinDate(candidateLateStart, candidate);
                            }
                            break;

                        case "FF":
                            if (successor.LateFinish.HasValue)
                            {
                                var candidate = ApplyWorkingDayOffset(
                                    successor.LateFinish.Value,
                                    -dependency.OffsetDays,
                                    calendar
                                );

                                candidateLateFinish = MinDate(candidateLateFinish, candidate);
                            }
                            break;

                        case "SF":
                            if (successor.LateFinish.HasValue)
                            {
                                var candidate = ApplyWorkingDayOffset(
                                    successor.LateFinish.Value,
                                    -dependency.OffsetDays,
                                    calendar
                                );

                                candidateLateStart = MinDate(candidateLateStart, candidate);
                            }
                            break;
                    }
                }

                if (task.Duration.HasValue)
                {
                    if (candidateLateFinish.HasValue)
                    {
                        task.LateFinish = NormalizeToWorkingDay(
                            candidateLateFinish.Value,
                            calendar,
                            forward: false
                        );

                        task.LateStart = SubtractWorkingDays(
                            task.LateFinish.Value,
                            task.Duration.Value,
                            calendar
                        );
                    }
                    else if (candidateLateStart.HasValue)
                    {
                        task.LateStart = NormalizeToWorkingDay(
                            candidateLateStart.Value,
                            calendar,
                            forward: true
                        );

                        task.LateFinish = AddWorkingDays(
                            task.LateStart.Value,
                            task.Duration.Value,
                            calendar
                        );
                    }
                }

                if (task.EarlyStart.HasValue && task.LateStart.HasValue)
                {
                    task.TotalFloat = CountWorkingDays(
                        task.EarlyStart.Value,
                        task.LateStart.Value,
                        calendar
                    );

                    task.IsCritical = task.TotalFloat == 0;
                }
            }

            foreach (var task in endTasks)
            {
                if (task.EarlyStart.HasValue && task.LateStart.HasValue)
                {
                    task.TotalFloat = CountWorkingDays(
                        task.EarlyStart.Value,
                        task.LateStart.Value,
                        calendar
                    );

                    task.IsCritical = task.TotalFloat == 0;
                }
            }

            // Deadline / retard / float négatif
            foreach (var task in tasks)
            {
                ApplyDeadlineStatus(task, calendar);
            }

            await _context.SaveChangesAsync();
        }

        private void ApplyDeadlineStatus(PlannerTask task, ProjectCalendar calendar)
        {
            if (!task.Deadline.HasValue || !task.EndDate.HasValue)
            {
                task.DelayDays = 0;
                task.IsLate = false;
                return;
            }

            var deadlineDate = NormalizeToWorkingDay(
                task.Deadline.Value,
                calendar,
                forward: false
            );

            var endDate = NormalizeToWorkingDay(
                task.EndDate.Value,
                calendar,
                forward: false
            );

            var deadlineFloat = CountWorkingDays(endDate, deadlineDate, calendar);

            task.TotalFloat = task.TotalFloat.HasValue
                ? Math.Min(task.TotalFloat.Value, deadlineFloat)
                : deadlineFloat;

            if (deadlineFloat < 0)
            {
                task.DelayDays = Math.Abs(deadlineFloat);
                task.IsLate = true;
            }
            else
            {
                task.DelayDays = 0;
                task.IsLate = false;
            }

            task.IsCritical = task.TotalFloat.HasValue && task.TotalFloat.Value <= 0;
        }

        private async Task<ProjectCalendar> GetOrCreateProjectCalendarForSchedulingAsync(int projectId)
        {
            var calendar = await _context.ProjectCalendars
                .Include(c => c.Exceptions)
                .FirstOrDefaultAsync(c => c.ProjectId == projectId);

            if (calendar != null)
                return calendar;

            calendar = new ProjectCalendar
            {
                ProjectId = projectId,
                WorkMonday = true,
                WorkTuesday = true,
                WorkWednesday = true,
                WorkThursday = true,
                WorkFriday = true,
                WorkSaturday = false,
                WorkSunday = false
            };

            _context.ProjectCalendars.Add(calendar);
            await _context.SaveChangesAsync();

            return calendar;
        }
    }
}
