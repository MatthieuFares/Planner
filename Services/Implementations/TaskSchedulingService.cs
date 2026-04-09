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
                .FirstOrDefaultAsync(t => t.Id == taskId);

            if (task == null) return;

            foreach (var dependency in task.Predecessors)
            {
                if (dependency.Type == DependencyType.FS)
                {
                    var predecessor = dependency.Predecessor;
                    var newStart = predecessor.EndDate;

                    if (task.StartDate < newStart)
                    {
                        var duration = task.EndDate - task.StartDate;

                        task.StartDate = newStart;
                        task.EndDate = newStart + duration;
                    }
                }
            }

            await _context.SaveChangesAsync();
        }
    }
}