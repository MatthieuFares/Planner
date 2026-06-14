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
            ValidateAssignmentValues(dto.WorkloadHours, dto.AllocationPercent);

            await ValidateAssignmentReferencesAsync(
                dto.TaskId,
                dto.ResourceId,
                dto.ResourceGroupId
            );

            await EnsureAssignmentDoesNotAlreadyExistAsync(
                dto.TaskId,
                dto.ResourceId,
                dto.ResourceGroupId,
                ignoredAssignmentId: null
            );

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

            var createdAssignment = await GetAssignmentWithDetailsAsync(assignment.Id);

            return MapToReadDto(createdAssignment!);
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

            return assignments
                .OrderBy(a => a.Resource?.Name ?? a.ResourceGroup?.Name ?? string.Empty)
                .Select(MapToReadDto);
        }

        public async Task<ResourceAssignmentReadDto?> UpdateAsync(int id, ResourceAssignmentUpdateDto dto)
        {
            ValidateAssignmentTarget(dto.ResourceId, dto.ResourceGroupId);
            ValidateAssignmentValues(dto.WorkloadHours, dto.AllocationPercent);

            var assignment = await _context.ResourceAssignments
                .FirstOrDefaultAsync(a => a.Id == id);

            if (assignment == null)
                return null;

            await ValidateAssignmentReferencesAsync(
                dto.TaskId,
                dto.ResourceId,
                dto.ResourceGroupId
            );

            await EnsureAssignmentDoesNotAlreadyExistAsync(
                dto.TaskId,
                dto.ResourceId,
                dto.ResourceGroupId,
                ignoredAssignmentId: id
            );

            assignment.TaskId = dto.TaskId;
            assignment.ResourceId = dto.ResourceId;
            assignment.ResourceGroupId = dto.ResourceGroupId;
            assignment.WorkloadHours = dto.WorkloadHours;
            assignment.AllocationPercent = dto.AllocationPercent;

            await _context.SaveChangesAsync();

            var updatedAssignment = await GetAssignmentWithDetailsAsync(id);

            return updatedAssignment == null
                ? null
                : MapToReadDto(updatedAssignment);
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

        private async Task ValidateAssignmentReferencesAsync(
            int taskId,
            int? resourceId,
            int? resourceGroupId)
        {
            var taskExists = await _context.Tasks.AnyAsync(t => t.Id == taskId);

            if (!taskExists)
                throw new InvalidOperationException("Tâche introuvable.");

            if (resourceId.HasValue)
            {
                var resourceExists = await _context.Resources
                    .AnyAsync(r => r.Id == resourceId.Value);

                if (!resourceExists)
                    throw new InvalidOperationException("Ressource introuvable.");
            }

            if (resourceGroupId.HasValue)
            {
                var groupExists = await _context.ResourceGroups
                    .AnyAsync(g => g.Id == resourceGroupId.Value);

                if (!groupExists)
                    throw new InvalidOperationException("Groupe de ressources introuvable.");
            }
        }

        private async Task EnsureAssignmentDoesNotAlreadyExistAsync(
            int taskId,
            int? resourceId,
            int? resourceGroupId,
            int? ignoredAssignmentId)
        {
            var alreadyExists = await _context.ResourceAssignments.AnyAsync(a =>
                a.TaskId == taskId &&
                a.ResourceId == resourceId &&
                a.ResourceGroupId == resourceGroupId &&
                (!ignoredAssignmentId.HasValue || a.Id != ignoredAssignmentId.Value)
            );

            if (alreadyExists)
            {
                throw new InvalidOperationException(
                    "Cette assignation existe déjà pour cette tâche."
                );
            }
        }

        private async Task<ResourceAssignment?> GetAssignmentWithDetailsAsync(int id)
        {
            return await _context.ResourceAssignments
                .Include(a => a.Task)
                .Include(a => a.Resource)
                .Include(a => a.ResourceGroup)
                .FirstOrDefaultAsync(a => a.Id == id);
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

        private static void ValidateAssignmentValues(decimal workloadHours, int allocationPercent)
        {
            if (workloadHours < 0)
            {
                throw new InvalidOperationException(
                    "La charge de travail ne peut pas être négative."
                );
            }

            if (allocationPercent < 0 || allocationPercent > 100)
            {
                throw new InvalidOperationException(
                    "Le pourcentage d'allocation doit être compris entre 0 et 100."
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

    internal static class ResourceAssignmentOrderingExtensions
    {
        public static string ResourceNameForOrdering(this ResourceAssignment assignment)
        {
            return assignment.Resource?.Name
                ?? assignment.ResourceGroup?.Name
                ?? string.Empty;
        }
    }
}