using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.Models;

namespace PlannerAPI.Services;

public class DependencyService
{
    private readonly AppDbContext _context;

    public DependencyService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Dependency>> GetAllAsync()
    {
        return await _context.Dependencies
            .Include(d => d.Predecessor)
            .Include(d => d.Successor)
            .ToListAsync();
    }

    public async Task<Dependency> CreateAsync(Dependency dependency)
    {
        _context.Dependencies.Add(dependency);
        await _context.SaveChangesAsync();
        return dependency;
    }
}