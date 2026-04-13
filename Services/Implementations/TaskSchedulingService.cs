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

        public async Task RecalculateTaskDatesAsync(int taskId)
        {
            var task = await _context.Tasks
                .Include(t => t.Predecessors)
                    .ThenInclude(d => d.Predecessor)
                .Include(t => t.Successors)
                    .ThenInclude(d => d.Successor)
                .FirstOrDefaultAsync(t => t.Id == taskId);

            if (task == null)
                return;

            DateTime? latestStartConstraint = null;

            foreach (var dependency in task.Predecessors)
            {
                if (dependency.Type == DependencyType.FS)
                {
                    var predecessor = dependency.Predecessor;

                    if (predecessor?.EndDate == null)
                        continue;

                    if (latestStartConstraint == null || predecessor.EndDate > latestStartConstraint)
                    {
                        latestStartConstraint = predecessor.EndDate;
                    }
                }

                if (dependency.Type == DependencyType.SS)
                {
                    var predecessor = dependency.Predecessor;

                    if (predecessor?.StartDate == null)
                        continue;

                    if (latestStartConstraint == null || predecessor.StartDate > latestStartConstraint)
                    {
                        latestStartConstraint = predecessor.StartDate;
                    }
                }
            }

            if (latestStartConstraint != null)
            {
                if (task.StartDate == null || task.StartDate < latestStartConstraint)
                {
                    task.StartDate = latestStartConstraint;
                }
            }

            if (task.StartDate.HasValue && task.Duration.HasValue)
            {
                task.EndDate = task.StartDate.Value.AddDays(task.Duration.Value);
            }

            await _context.SaveChangesAsync();

            var successorIds = task.Successors
                .Select(s => s.SuccessorId)
                .Distinct()
                .ToList();

            foreach (var successorId in successorIds)
            {
                await RecalculateTaskDatesAsync(successorId);
            }
        }
    }
}