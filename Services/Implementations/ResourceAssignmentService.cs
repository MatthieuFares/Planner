using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ResourceAssignmentService
        : IResourceAssignmentService
    {
        private readonly AppDbContext _context;

        public ResourceAssignmentService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<ResourceAssignmentReadDto> CreateAsync(
            ResourceAssignmentCreateDto dto
        )
        {
            ValidateAssignmentTarget(
                dto.ResourceId,
                dto.ResourceGroupId
            );

            ValidateAssignmentValues(
                dto.WorkloadHours,
                dto.AllocationPercent
            );

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

            var createdAssignment =
                await GetAssignmentWithDetailsAsync(
                    assignment.Id
                );

            return MapToReadDto(createdAssignment!);
        }

        public async Task<
            IEnumerable<ResourceAssignmentReadDto>
        > GetByTaskIdAsync(int taskId)
        {
            var taskExists = await _context.Tasks
                .AsNoTracking()
                .AnyAsync(task => task.Id == taskId);

            if (!taskExists)
            {
                throw new InvalidOperationException(
                    "Tâche introuvable."
                );
            }

            var assignments =
                await _context.ResourceAssignments
                    .AsNoTracking()
                    .Include(assignment => assignment.Task)
                    .Include(assignment => assignment.Resource)
                    .Include(
                        assignment =>
                            assignment.ResourceGroup
                    )
                    .Where(
                        assignment =>
                            assignment.TaskId == taskId
                    )
                    .ToListAsync();

            return assignments
                .OrderBy(
                    assignment =>
                        assignment.Resource?.Name
                        ?? assignment.ResourceGroup?.Name
                        ?? string.Empty
                )
                .Select(MapToReadDto);
        }

        public async Task<
            IEnumerable<ResourceAssignmentReadDto>
        > GetByProjectIdAsync(int projectId)
        {
            var projectExists = await _context.Projects
                .AsNoTracking()
                .AnyAsync(project => project.Id == projectId);

            if (!projectExists)
            {
                throw new InvalidOperationException(
                    "Projet introuvable."
                );
            }

            var assignments =
                await _context.ResourceAssignments
                    .AsNoTracking()
                    .Include(assignment => assignment.Task)
                    .Include(assignment => assignment.Resource)
                    .Include(
                        assignment =>
                            assignment.ResourceGroup
                    )
                    .Where(
                        assignment =>
                            assignment.Task != null
                            && assignment.Task.ProjectId
                                == projectId
                    )
                    .ToListAsync();

            return assignments
                .OrderBy(
                    assignment =>
                        assignment.Task?.Title
                        ?? string.Empty
                )
                .ThenBy(
                    assignment =>
                        assignment.Resource?.Name
                        ?? assignment.ResourceGroup?.Name
                        ?? string.Empty
                )
                .Select(MapToReadDto);
        }

        public async Task<ResourceAssignmentReadDto?> UpdateAsync(
            int id,
            ResourceAssignmentUpdateDto dto
        )
        {
            ValidateAssignmentTarget(
                dto.ResourceId,
                dto.ResourceGroupId
            );

            ValidateAssignmentValues(
                dto.WorkloadHours,
                dto.AllocationPercent
            );

            var assignment =
                await _context.ResourceAssignments
                    .FirstOrDefaultAsync(
                        current => current.Id == id
                    );

            if (assignment == null)
            {
                return null;
            }

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
            assignment.ResourceGroupId =
                dto.ResourceGroupId;
            assignment.WorkloadHours =
                dto.WorkloadHours;
            assignment.AllocationPercent =
                dto.AllocationPercent;

            await _context.SaveChangesAsync();

            var updatedAssignment =
                await GetAssignmentWithDetailsAsync(id);

            return updatedAssignment == null
                ? null
                : MapToReadDto(updatedAssignment);
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var assignment =
                await _context.ResourceAssignments
                    .FindAsync(id);

            if (assignment == null)
            {
                return false;
            }

            _context.ResourceAssignments.Remove(assignment);

            await _context.SaveChangesAsync();

            return true;
        }

        private async Task ValidateAssignmentReferencesAsync(
            int taskId,
            int? resourceId,
            int? resourceGroupId
        )
        {
            var taskExists = await _context.Tasks
                .AsNoTracking()
                .AnyAsync(task => task.Id == taskId);

            if (!taskExists)
            {
                throw new InvalidOperationException(
                    "Tâche introuvable."
                );
            }

            if (resourceId.HasValue)
            {
                var resourceExists =
                    await _context.Resources
                        .AsNoTracking()
                        .AnyAsync(
                            resource =>
                                resource.Id
                                == resourceId.Value
                        );

                if (!resourceExists)
                {
                    throw new InvalidOperationException(
                        "Ressource introuvable."
                    );
                }
            }

            if (resourceGroupId.HasValue)
            {
                var group = await _context.ResourceGroups
                    .AsNoTracking()
                    .Include(
                        resourceGroup =>
                            resourceGroup.Members
                    )
                    .FirstOrDefaultAsync(
                        resourceGroup =>
                            resourceGroup.Id
                            == resourceGroupId.Value
                    );

                if (group == null)
                {
                    throw new InvalidOperationException(
                        "Groupe de ressources introuvable."
                    );
                }

                if (group.Members.Count == 0)
                {
                    throw new InvalidOperationException(
                        "Un groupe vide ne peut pas être "
                        + "assigné à une tâche."
                    );
                }
            }
        }

        private async Task
            EnsureAssignmentDoesNotAlreadyExistAsync(
                int taskId,
                int? resourceId,
                int? resourceGroupId,
                int? ignoredAssignmentId
            )
        {
            var alreadyExists =
                await _context.ResourceAssignments
                    .AsNoTracking()
                    .AnyAsync(
                        assignment =>
                            assignment.TaskId == taskId
                            && assignment.ResourceId
                                == resourceId
                            && assignment.ResourceGroupId
                                == resourceGroupId
                            && (
                                !ignoredAssignmentId.HasValue
                                || assignment.Id
                                    != ignoredAssignmentId.Value
                            )
                    );

            if (alreadyExists)
            {
                throw new InvalidOperationException(
                    "Cette assignation existe déjà "
                    + "pour cette tâche."
                );
            }
        }

        private async Task<ResourceAssignment?>
            GetAssignmentWithDetailsAsync(int id)
        {
            return await _context.ResourceAssignments
                .AsNoTracking()
                .Include(assignment => assignment.Task)
                .Include(assignment => assignment.Resource)
                .Include(
                    assignment =>
                        assignment.ResourceGroup
                )
                .FirstOrDefaultAsync(
                    assignment => assignment.Id == id
                );
        }

        private static void ValidateAssignmentTarget(
            int? resourceId,
            int? resourceGroupId
        )
        {
            if (
                !resourceId.HasValue
                && !resourceGroupId.HasValue
            )
            {
                throw new InvalidOperationException(
                    "Une assignation doit cibler "
                    + "une ressource ou un groupe."
                );
            }

            if (
                resourceId.HasValue
                && resourceGroupId.HasValue
            )
            {
                throw new InvalidOperationException(
                    "Une assignation ne peut pas cibler "
                    + "une ressource et un groupe "
                    + "en même temps."
                );
            }
        }

        private static void ValidateAssignmentValues(
            decimal workloadHours,
            int allocationPercent
        )
        {
            if (workloadHours < 0)
            {
                throw new InvalidOperationException(
                    "La charge de travail "
                    + "ne peut pas être négative."
                );
            }

            if (
                allocationPercent < 0
                || allocationPercent > 100
            )
            {
                throw new InvalidOperationException(
                    "Le pourcentage d'allocation doit "
                    + "être compris entre 0 et 100."
                );
            }
        }

        private static ResourceAssignmentReadDto MapToReadDto(
            ResourceAssignment assignment
        )
        {
            return new ResourceAssignmentReadDto
            {
                Id = assignment.Id,
                TaskId = assignment.TaskId,
                TaskTitle = assignment.Task?.Title,
                ResourceId = assignment.ResourceId,
                ResourceName = assignment.Resource?.Name,
                ResourceGroupId =
                    assignment.ResourceGroupId,
                ResourceGroupName =
                    assignment.ResourceGroup?.Name,
                WorkloadHours =
                    assignment.WorkloadHours,
                AllocationPercent =
                    assignment.AllocationPercent
            };
        }
    }
}