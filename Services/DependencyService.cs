using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.Models;

namespace PlannerAPI.Services;

public class TaskDependencyService
{
    private readonly AppDbContext _context;

    public TaskDependencyService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<TaskDependency>> GetAllAsync()
    {
        return await _context.TaskDependencies
            .Include(d => d.Predecessor)
            .Include(d => d.Successor)
            .ToListAsync();
    }

    public async Task<TaskDependency> CreateAsync(TaskDependency TaskDependency)
    {
        _context.TaskDependencies.Add(TaskDependency);
        await _context.SaveChangesAsync();
        return TaskDependency;
    }
}