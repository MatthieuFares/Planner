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

        private bool IsWorkingDay(DateTime date)
        {
            return date.DayOfWeek != DayOfWeek.Saturday &&
                   date.DayOfWeek != DayOfWeek.Sunday;
        }

        private DateTime AddWorkingDays(DateTime date, int days)
        {
            var currentDate = date;
            var remainingDays = days;

            while (remainingDays > 0)
            {
                currentDate = currentDate.AddDays(1);

                if (IsWorkingDay(currentDate))
                    remainingDays--;
            }

            return currentDate;
        }

        private DateTime SubtractWorkingDays(DateTime date, int days)
        {
            var currentDate = date;
            var remainingDays = days;

            while (remainingDays > 0)
            {
                currentDate = currentDate.AddDays(-1);

                if (IsWorkingDay(currentDate))
                    remainingDays--;
            }

            return currentDate;
        }

        public async Task RecalculateTaskDatesAsync(int taskId)
        {
            await RecalculateTaskDatesInternalAsync(taskId, new HashSet<int>());

            var task = await _context.Tasks.FirstOrDefaultAsync(t => t.Id == taskId);

            if (task != null)
            {
                await CalculateCriticalPathAsync(task.ProjectId);
            }
        }

        private async Task RecalculateTaskDatesInternalAsync(int taskId, HashSet<int> visited)
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
                                predecessor.EndDate.Value.AddDays(dependency.OffsetDays)
                            );
                        }
                        break;

                    case "SS":
                        if (predecessor.StartDate.HasValue)
                        {
                            latestStartConstraint = MaxDate(
                                latestStartConstraint,
                                predecessor.StartDate.Value.AddDays(dependency.OffsetDays)
                            );
                        }
                        break;

                    case "FF":
                        if (predecessor.EndDate.HasValue)
                        {
                            latestEndConstraint = MaxDate(
                                latestEndConstraint,
                                predecessor.EndDate.Value.AddDays(dependency.OffsetDays)
                            );
                        }
                        break;

                    case "SF":
                        if (predecessor.StartDate.HasValue)
                        {
                            latestEndConstraint = MaxDate(
                                latestEndConstraint,
                                predecessor.StartDate.Value.AddDays(dependency.OffsetDays)
                            );
                        }
                        break;
                }
            }

            ApplySchedulingRules(task, latestStartConstraint, latestEndConstraint);

            await _context.SaveChangesAsync();

            var successorIds = task.Successors
                .Select(s => s.SuccessorId)
                .Distinct()
                .ToList();

            foreach (var successorId in successorIds)
            {
                await RecalculateTaskDatesInternalAsync(successorId, visited);
            }
        }

        private void ApplySchedulingRules(
            PlannerTask task,
            DateTime? latestStartConstraint,
            DateTime? latestEndConstraint)
        {
            if (!task.Duration.HasValue)
                return;

            var duration = task.Duration.Value;

            if (latestStartConstraint.HasValue && latestEndConstraint.HasValue)
            {
                var expectedEnd = AddWorkingDays(latestStartConstraint.Value, duration);

                if (expectedEnd > latestEndConstraint.Value)
                {
                    throw new InvalidOperationException(
                        $"Conflit de planification pour la tâche {task.Id} : " +
                        "les contraintes de début et de fin sont incompatibles avec la durée."
                    );
                }

                task.StartDate = latestStartConstraint.Value;
                task.EndDate = AddWorkingDays(task.StartDate.Value, duration);
                return;
            }

            if (latestStartConstraint.HasValue)
            {
                task.StartDate = latestStartConstraint.Value;
                task.EndDate = AddWorkingDays(task.StartDate.Value, duration);
                return;
            }

            if (latestEndConstraint.HasValue)
            {
                task.EndDate = latestEndConstraint.Value;
                task.StartDate = SubtractWorkingDays(task.EndDate.Value, duration);
                return;
            }

            if (task.StartDate.HasValue)
            {
                task.EndDate = AddWorkingDays(task.StartDate.Value, duration);
            }
            else if (task.EndDate.HasValue)
            {
                task.StartDate = SubtractWorkingDays(task.EndDate.Value, duration);
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
                task.LateFinish = projectEndDate.Value;

                if (task.Duration.HasValue)
                {
                    task.LateStart = SubtractWorkingDays(
                        task.LateFinish.Value,
                        task.Duration.Value
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
                                var candidate = successor.LateStart.Value.AddDays(-dependency.OffsetDays);
                                candidateLateFinish = MinDate(candidateLateFinish, candidate);
                            }
                            break;

                        case "SS":
                            if (successor.LateStart.HasValue)
                            {
                                var candidate = successor.LateStart.Value.AddDays(-dependency.OffsetDays);
                                candidateLateStart = MinDate(candidateLateStart, candidate);
                            }
                            break;

                        case "FF":
                            if (successor.LateFinish.HasValue)
                            {
                                var candidate = successor.LateFinish.Value.AddDays(-dependency.OffsetDays);
                                candidateLateFinish = MinDate(candidateLateFinish, candidate);
                            }
                            break;

                        case "SF":
                            if (successor.LateFinish.HasValue)
                            {
                                var candidate = successor.LateFinish.Value.AddDays(-dependency.OffsetDays);
                                candidateLateStart = MinDate(candidateLateStart, candidate);
                            }
                            break;
                    }
                }

                if (task.Duration.HasValue)
                {
                    if (candidateLateFinish.HasValue)
                    {
                        task.LateFinish = candidateLateFinish.Value;
                        task.LateStart = SubtractWorkingDays(
                            task.LateFinish.Value,
                            task.Duration.Value
                        );
                    }
                    else if (candidateLateStart.HasValue)
                    {
                        task.LateStart = candidateLateStart.Value;
                        task.LateFinish = AddWorkingDays(
                            task.LateStart.Value,
                            task.Duration.Value
                        );
                    }
                }

                if (task.EarlyStart.HasValue && task.LateStart.HasValue)
                {
                    task.TotalFloat = (task.LateStart.Value - task.EarlyStart.Value).Days;
                    task.IsCritical = task.TotalFloat == 0;
                }
            }

            foreach (var task in endTasks)
            {
                if (task.EarlyStart.HasValue && task.LateStart.HasValue)
                {
                    task.TotalFloat = (task.LateStart.Value - task.EarlyStart.Value).Days;
                    task.IsCritical = task.TotalFloat == 0;
                }
            }

            await _context.SaveChangesAsync();
        }
    }
}