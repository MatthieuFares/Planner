using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ResourceAnalysisService : IResourceAnalysisService
    {
        private readonly AppDbContext _context;

        public ResourceAnalysisService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<ProjectResourceAnalysisDto?> GetProjectAnalysisAsync(int projectId)
        {
            var projectExists = await _context.Projects.AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return null;

            var assignments = await _context.ResourceAssignments
                .Include(a => a.Resource)
                .Include(a => a.Task)
                .Where(a => a.Task != null && a.Task.ProjectId == projectId)
                .ToListAsync();

            var resourceStats = assignments
                .Where(a => a.Resource != null)
                .GroupBy(a => a.ResourceId)
                .Select(g =>
                {
                    var resource = g.First().Resource!;
                    var assignedHours = g.Sum(a => a.WorkloadHours);
                    var estimatedCost = resource.CostPerHour.HasValue
                        ? assignedHours * resource.CostPerHour.Value
                        : 0;

                    decimal? utilizationPercent = null;
                    var isOverloaded = false;

                    if (resource.CapacityHoursPerWeek.HasValue && resource.CapacityHoursPerWeek.Value > 0)
                    {
                        utilizationPercent = Math.Round(
                            assignedHours / resource.CapacityHoursPerWeek.Value * 100,
                            2
                        );

                        isOverloaded = utilizationPercent > 100;
                    }

                    return new ResourceWorkloadDto
                    {
                        ResourceId = resource.Id,
                        ResourceName = resource.Name,
                        ResourceType = resource.Type,
                        AssignedHours = assignedHours,
                        CapacityHoursPerWeek = resource.CapacityHoursPerWeek,
                        CostPerHour = resource.CostPerHour,
                        EstimatedCost = estimatedCost,
                        UtilizationPercent = utilizationPercent,
                        IsOverloaded = isOverloaded
                    };
                })
                .OrderByDescending(r => r.AssignedHours)
                .ToList();

            return new ProjectResourceAnalysisDto
            {
                ProjectId = projectId,
                TotalWorkloadHours = resourceStats.Sum(r => r.AssignedHours),
                EstimatedCost = resourceStats.Sum(r => r.EstimatedCost),
                Resources = resourceStats
            };
        }
    }
}