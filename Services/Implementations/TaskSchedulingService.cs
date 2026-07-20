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

            // Une exception précise est prioritaire sur une période.
            // Elle permet notamment de rendre travaillé un jour inclus
            // dans une période normalement non ouvrée.
            var exception = calendar.Exceptions?
                .FirstOrDefault(e => e.Date.Date == normalizedDate);

            if (exception != null)
                return exception.IsWorkingDay;

            var isInsideNonWorkingPeriod = calendar.Periods?
                .Any(period =>
                    period.StartDate.Date <= normalizedDate &&
                    period.EndDate.Date >= normalizedDate) == true;

            if (isInsideNonWorkingPeriod)
                return false;

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

            // Pour la version test, on privilégie la cohérence complète.
            // Un recalcul récursif avec un simple HashSet peut laisser un
            // successeur partagé dans un état périmé sur un graphe en losange.
            await RecalculateProjectAsync(initialTask.ProjectId);
        }

        public async Task RecalculateProjectAsync(int projectId)
        {
            var projectExists = await _context.Projects
                .AsNoTracking()
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return;

            var calendar = await GetOrCreateProjectCalendarForSchedulingAsync(
                projectId
            );

            var taskIds = await _context.Tasks
                .AsNoTracking()
                .Where(t => t.ProjectId == projectId)
                .Select(t => t.Id)
                .ToListAsync();

            if (!taskIds.Any())
                return;

            var dependencies = await _context.TaskDependencies
                .AsNoTracking()
                .Where(d =>
                    taskIds.Contains(d.PredecessorId) &&
                    taskIds.Contains(d.SuccessorId))
                .Select(d => new
                {
                    d.PredecessorId,
                    d.SuccessorId
                })
                .ToListAsync();

            var incomingCount = taskIds.ToDictionary(
                taskId => taskId,
                _ => 0
            );

            var successorsByTask = taskIds.ToDictionary(
                taskId => taskId,
                _ => new List<int>()
            );

            foreach (var dependency in dependencies)
            {
                incomingCount[dependency.SuccessorId]++;
                successorsByTask[dependency.PredecessorId]
                    .Add(dependency.SuccessorId);
            }

            var readyTaskIds = new SortedSet<int>(
                incomingCount
                    .Where(pair => pair.Value == 0)
                    .Select(pair => pair.Key)
            );

            var orderedTaskIds = new List<int>(taskIds.Count);

            while (readyTaskIds.Count > 0)
            {
                var currentTaskId = readyTaskIds.Min;
                readyTaskIds.Remove(currentTaskId);

                orderedTaskIds.Add(currentTaskId);

                foreach (var successorId in successorsByTask[currentTaskId])
                {
                    incomingCount[successorId]--;

                    if (incomingCount[successorId] == 0)
                    {
                        readyTaskIds.Add(successorId);
                    }
                }
            }

            if (orderedTaskIds.Count != taskIds.Count)
            {
                throw new InvalidOperationException(
                    "Impossible de recalculer le planning : " +
                    "un cycle de dépendances a été détecté."
                );
            }

            foreach (var orderedTaskId in orderedTaskIds)
            {
                await RecalculateSingleTaskDatesAsync(
                    orderedTaskId,
                    calendar
                );
            }

            await CalculateCriticalPathAsync(projectId);
        }

        private async Task<List<int>> RecalculateSingleTaskDatesAsync(
            int taskId,
            ProjectCalendar calendar)
        {
            var task = await _context.Tasks
                .Include(t => t.Predecessors)
                    .ThenInclude(d => d.Predecessor)
                .Include(t => t.Successors)
                    .ThenInclude(d => d.Successor)
                .FirstOrDefaultAsync(t => t.Id == taskId);

            if (task == null)
                return new List<int>();

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
                                    dependency.OffsetDays + 1,
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

            ApplySchedulingRules(
                task,
                latestStartConstraint,
                latestEndConstraint,
                calendar
            );

            await _context.SaveChangesAsync();

            return task.Successors
                .Select(s => s.SuccessorId)
                .Distinct()
                .ToList();
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

            if (duration <= 0)
            {
                throw new InvalidOperationException(
                    $"La durée de la tâche {task.Id} doit être supérieure à zéro."
                );
            }

            // Convention métier inclusive :
            // 1 jour commencé lundi se termine lundi.
            // 5 jours commencés lundi se terminent vendredi.
            var durationOffset = duration - 1;

            if (latestStartConstraint.HasValue && latestEndConstraint.HasValue)
            {
                var startConstraint = NormalizeToWorkingDay(
                    latestStartConstraint.Value,
                    calendar,
                    forward: true
                );

                // Une contrainte FF/SF est une date de fin minimale.
                var endConstraint = NormalizeToWorkingDay(
                    latestEndConstraint.Value,
                    calendar,
                    forward: true
                );

                var startRequiredByEnd = SubtractWorkingDays(
                    endConstraint,
                    durationOffset,
                    calendar
                );

                var effectiveStart = MaxDate(
                    startConstraint,
                    startRequiredByEnd
                );

                task.StartDate = NormalizeToWorkingDay(
                    effectiveStart,
                    calendar,
                    forward: true
                );

                task.EndDate = AddWorkingDays(
                    task.StartDate.Value,
                    durationOffset,
                    calendar
                );

                return;
            }

            if (latestStartConstraint.HasValue)
            {
                task.StartDate = NormalizeToWorkingDay(
                    latestStartConstraint.Value,
                    calendar,
                    forward: true
                );

                task.EndDate = AddWorkingDays(
                    task.StartDate.Value,
                    durationOffset,
                    calendar
                );

                return;
            }

            if (latestEndConstraint.HasValue)
            {
                task.EndDate = NormalizeToWorkingDay(
                    latestEndConstraint.Value,
                    calendar,
                    forward: true
                );

                task.StartDate = SubtractWorkingDays(
                    task.EndDate.Value,
                    durationOffset,
                    calendar
                );

                return;
            }

            if (task.StartDate.HasValue)
            {
                task.StartDate = NormalizeToWorkingDay(
                    task.StartDate.Value,
                    calendar,
                    forward: true
                );

                task.EndDate = AddWorkingDays(
                    task.StartDate.Value,
                    durationOffset,
                    calendar
                );
            }
            else if (task.EndDate.HasValue)
            {
                task.EndDate = NormalizeToWorkingDay(
                    task.EndDate.Value,
                    calendar,
                    forward: false
                );

                task.StartDate = SubtractWorkingDays(
                    task.EndDate.Value,
                    durationOffset,
                    calendar
                );
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
                    if (task.Duration.Value <= 0)
                    {
                        throw new InvalidOperationException(
                            $"La durée de la tâche {task.Id} doit être supérieure à zéro."
                        );
                    }

                    task.LateStart = SubtractWorkingDays(
                        task.LateFinish.Value,
                        task.Duration.Value - 1,
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
                                    -(dependency.OffsetDays + 1),
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
                    if (task.Duration.Value <= 0)
                    {
                        throw new InvalidOperationException(
                            $"La durée de la tâche {task.Id} doit être supérieure à zéro."
                        );
                    }

                    var durationOffset = task.Duration.Value - 1;
                    DateTime? effectiveLateStart = null;

                    if (candidateLateStart.HasValue)
                    {
                        effectiveLateStart = NormalizeToWorkingDay(
                            candidateLateStart.Value,
                            calendar,
                            forward: false
                        );
                    }

                    if (candidateLateFinish.HasValue)
                    {
                        var normalizedLateFinish = NormalizeToWorkingDay(
                            candidateLateFinish.Value,
                            calendar,
                            forward: false
                        );

                        var lateStartFromFinish = SubtractWorkingDays(
                            normalizedLateFinish,
                            durationOffset,
                            calendar
                        );

                        effectiveLateStart = MinDate(
                            effectiveLateStart,
                            lateStartFromFinish
                        );
                    }

                    if (effectiveLateStart.HasValue)
                    {
                        task.LateStart = NormalizeToWorkingDay(
                            effectiveLateStart.Value,
                            calendar,
                            forward: false
                        );

                        task.LateFinish = AddWorkingDays(
                            task.LateStart.Value,
                            durationOffset,
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
                .Include(c => c.Periods)
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