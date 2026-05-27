using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ResourceAssignmentService : IResourceAssignmentService
    {
        private readonly AppDbContext _context;

        public ResourceAssignmentService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<ResourceAssignmentReadDto> CreateAsync(ResourceAssignmentCreateDto dto)
        {
            ValidateAssignmentTarget(dto.ResourceId, dto.ResourceGroupId);

            var taskExists = await _context.Tasks.AnyAsync(t => t.Id == dto.TaskId);

            if (!taskExists)
                throw new InvalidOperationException("Tâche introuvable.");

            if (dto.ResourceId.HasValue)
            {
                var resourceExists = await _context.Resources
                    .AnyAsync(r => r.Id == dto.ResourceId.Value);

                if (!resourceExists)
                    throw new InvalidOperationException("Ressource introuvable.");
            }

            if (dto.ResourceGroupId.HasValue)
            {
                var groupExists = await _context.ResourceGroups
                    .AnyAsync(g => g.Id == dto.ResourceGroupId.Value);

                if (!groupExists)
                    throw new InvalidOperationException("Groupe de ressources introuvable.");
            }

            var assignment = new ResourceAssignment
            {
                TaskId = dto.TaskId,
                ResourceId = dto.ResourceId,
                ResourceGroupId = dto.ResourceGroupId,
                WorkloadHours = dto.WorkloadHours,
                AllocationPercent = dto.AllocationPercent
            };

            _context.ResourceAssignments.Add(assignment);

            await _context.SaveChangesAsync();

            var createdAssignment = await _context.ResourceAssignments
                .Include(a => a.Task)
                .Include(a => a.Resource)
                .Include(a => a.ResourceGroup)
                .FirstAsync(a => a.Id == assignment.Id);

            return MapToReadDto(createdAssignment);
        }

        public async Task<IEnumerable<ResourceAssignmentReadDto>> GetByTaskIdAsync(int taskId)
        {
            var taskExists = await _context.Tasks.AnyAsync(t => t.Id == taskId);

            if (!taskExists)
                throw new InvalidOperationException("Tâche introuvable.");

            var assignments = await _context.ResourceAssignments
                .Include(a => a.Task)
                .Include(a => a.Resource)
                .Include(a => a.ResourceGroup)
                .Where(a => a.TaskId == taskId)
                .ToListAsync();

            return assignments.Select(MapToReadDto);
        }

        public async Task<bool> UpdateAsync(int id, ResourceAssignmentUpdateDto dto)
        {
            ValidateAssignmentTarget(dto.ResourceId, dto.ResourceGroupId);

            var assignment = await _context.ResourceAssignments
                .FirstOrDefaultAsync(a => a.Id == id);

            if (assignment == null)
                return false;

            var taskExists = await _context.Tasks.AnyAsync(t => t.Id == dto.TaskId);

            if (!taskExists)
                throw new InvalidOperationException("Tâche introuvable.");

            if (dto.ResourceId.HasValue)
            {
                var resourceExists = await _context.Resources
                    .AnyAsync(r => r.Id == dto.ResourceId.Value);

                if (!resourceExists)
                    throw new InvalidOperationException("Ressource introuvable.");
            }

            if (dto.ResourceGroupId.HasValue)
            {
                var groupExists = await _context.ResourceGroups
                    .AnyAsync(g => g.Id == dto.ResourceGroupId.Value);

                if (!groupExists)
                    throw new InvalidOperationException("Groupe de ressources introuvable.");
            }

            assignment.TaskId = dto.TaskId;
            assignment.ResourceId = dto.ResourceId;
            assignment.ResourceGroupId = dto.ResourceGroupId;
            assignment.WorkloadHours = dto.WorkloadHours;
            assignment.AllocationPercent = dto.AllocationPercent;

            await _context.SaveChangesAsync();

            return true;
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var assignment = await _context.ResourceAssignments.FindAsync(id);

            if (assignment == null)
                return false;

            _context.ResourceAssignments.Remove(assignment);

            await _context.SaveChangesAsync();

            return true;
        }

        private static void ValidateAssignmentTarget(int? resourceId, int? resourceGroupId)
        {
            if (!resourceId.HasValue && !resourceGroupId.HasValue)
            {
                throw new InvalidOperationException(
                    "Une assignation doit cibler une ressource ou un groupe."
                );
            }

            if (resourceId.HasValue && resourceGroupId.HasValue)
            {
                throw new InvalidOperationException(
                    "Une assignation ne peut pas cibler une ressource et un groupe en même temps."
                );
            }
        }

        private static ResourceAssignmentReadDto MapToReadDto(ResourceAssignment assignment)
        {
            return new ResourceAssignmentReadDto
            {
                Id = assignment.Id,

                TaskId = assignment.TaskId,
                TaskTitle = assignment.Task?.Title,

                ResourceId = assignment.ResourceId,
                ResourceName = assignment.Resource?.Name,

                ResourceGroupId = assignment.ResourceGroupId,
                ResourceGroupName = assignment.ResourceGroup?.Name,

                WorkloadHours = assignment.WorkloadHours,
                AllocationPercent = assignment.AllocationPercent
            };
        }
    }
}