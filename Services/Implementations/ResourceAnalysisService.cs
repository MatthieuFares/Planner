using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ResourceAnalysisService
        : IResourceAnalysisService
    {
        private readonly AppDbContext _context;

        public ResourceAnalysisService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<ProjectResourceAnalysisDto?>
            GetProjectAnalysisAsync(int projectId)
        {
            var projectExists = await _context.Projects
                .AsNoTracking()
                .AnyAsync(project => project.Id == projectId);

            if (!projectExists)
            {
                return null;
            }

            var assignments =
                await _context.ResourceAssignments
                    .AsNoTracking()
                    .Include(assignment => assignment.Resource)
                    .Include(assignment => assignment.Task)
                    .Include(
                        assignment =>
                            assignment.ResourceGroup
                    )
                    .ThenInclude(
                        resourceGroup =>
                            resourceGroup!.Members
                    )
                    .ThenInclude(
                        member => member.Resource
                    )
                    .Where(
                        assignment =>
                            assignment.Task != null
                            && assignment.Task.ProjectId
                                == projectId
                    )
                    .ToListAsync();

            var contributions =
                new List<ResourceWorkloadContribution>();

            foreach (var assignment in assignments)
            {
                if (assignment.Resource != null)
                {
                    contributions.Add(
                        new ResourceWorkloadContribution(
                            assignment.Resource,
                            assignment.WorkloadHours
                        )
                    );

                    continue;
                }

                if (assignment.ResourceGroup == null)
                {
                    continue;
                }

                var members = assignment.ResourceGroup.Members
                    .Where(
                        member => member.Resource != null
                    )
                    .GroupBy(member => member.ResourceId)
                    .Select(group => group.First())
                    .ToList();

                if (members.Count == 0)
                {
                    continue;
                }

                var workloadPerMember =
                    assignment.WorkloadHours
                    / members.Count;

                foreach (var member in members)
                {
                    contributions.Add(
                        new ResourceWorkloadContribution(
                            member.Resource!,
                            workloadPerMember
                        )
                    );
                }
            }

            var resourceStats = contributions
                .GroupBy(
                    contribution =>
                        contribution.Resource.Id
                )
                .Select(group =>
                {
                    var resource =
                        group.First().Resource;

                    var assignedHours = group.Sum(
                        contribution =>
                            contribution.WorkloadHours
                    );

                    var estimatedCost =
                        resource.CostPerHour.HasValue
                            ? assignedHours
                                * resource.CostPerHour.Value
                            : 0;

                    decimal? utilizationPercent = null;
                    var isOverloaded = false;

                    if (
                        resource.CapacityHoursPerWeek.HasValue
                        && resource.CapacityHoursPerWeek.Value > 0
                    )
                    {
                        utilizationPercent = Math.Round(
                            assignedHours
                            / resource
                                .CapacityHoursPerWeek
                                .Value
                            * 100,
                            2
                        );

                        isOverloaded =
                            utilizationPercent > 100;
                    }

                    return new ResourceWorkloadDto
                    {
                        ResourceId = resource.Id,
                        ResourceName = resource.Name,
                        ResourceType = resource.Type,
                        AssignedHours = assignedHours,
                        CapacityHoursPerWeek =
                            resource.CapacityHoursPerWeek,
                        CostPerHour =
                            resource.CostPerHour,
                        EstimatedCost = estimatedCost,
                        UtilizationPercent =
                            utilizationPercent,
                        IsOverloaded = isOverloaded
                    };
                })
                .OrderByDescending(
                    resource => resource.AssignedHours
                )
                .ToList();

            return new ProjectResourceAnalysisDto
            {
                ProjectId = projectId,
                TotalWorkloadHours = resourceStats.Sum(
                    resource => resource.AssignedHours
                ),
                EstimatedCost = resourceStats.Sum(
                    resource => resource.EstimatedCost
                ),
                Resources = resourceStats
            };
        }

        private sealed record
            ResourceWorkloadContribution(
                Resource Resource,
                decimal WorkloadHours
            );
    }
}