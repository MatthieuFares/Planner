using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.Models;

namespace PlannerAPI.Services;

public class TaskService
{
    private readonly AppDbContext _context;

    public TaskService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<PlannerTask>> GetAllAsync()
    {
        return await _context.Tasks
            .Include(t => t.Project)
            .ToListAsync();
    }

    public async Task<PlannerTask?> GetByIdAsync(int id)
    {
        return await _context.Tasks
            .Include(t => t.Project)
            .FirstOrDefaultAsync(t => t.Id == id);
    }

    public async Task<PlannerTask> CreateAsync(PlannerTask task)
    {
        _context.Tasks.Add(task);
        await _context.SaveChangesAsync();
        return task;
    }
}