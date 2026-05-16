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
            var taskExists = await _context.Tasks.AnyAsync(t => t.Id == dto.TaskId);

            if (!taskExists)
                throw new InvalidOperationException("Tâche introuvable.");

            var resource = await _context.Resources.FindAsync(dto.ResourceId);

            if (resource == null)
                throw new InvalidOperationException("Ressource introuvable.");

            var assignment = new ResourceAssignment
            {
                TaskId = dto.TaskId,
                ResourceId = dto.ResourceId,
                WorkloadHours = dto.WorkloadHours,
                AllocationPercent = dto.AllocationPercent
            };

            _context.ResourceAssignments.Add(assignment);

            await _context.SaveChangesAsync();

            return new ResourceAssignmentReadDto
            {
                Id = assignment.Id,
                TaskId = assignment.TaskId,
                ResourceId = assignment.ResourceId,
                ResourceName = resource.Name,
                WorkloadHours = assignment.WorkloadHours,
                AllocationPercent = assignment.AllocationPercent
            };
        }

        public async Task<IEnumerable<ResourceAssignmentReadDto>> GetByTaskIdAsync(int taskId)
        {
            return await _context.ResourceAssignments
                .Include(a => a.Resource)
                .Where(a => a.TaskId == taskId)
                .Select(a => new ResourceAssignmentReadDto
                {
                    Id = a.Id,
                    TaskId = a.TaskId,
                    ResourceId = a.ResourceId,
                    ResourceName = a.Resource!.Name,
                    WorkloadHours = a.WorkloadHours,
                    AllocationPercent = a.AllocationPercent
                })
                .ToListAsync();
        }

        public async Task<bool> UpdateAsync(int id, ResourceAssignmentUpdateDto dto)
        {
            var assignment = await _context.ResourceAssignments.FindAsync(id);

            if (assignment == null)
                return false;

            var taskExists = await _context.Tasks.AnyAsync(t => t.Id == dto.TaskId);

            if (!taskExists)
                return false;

            var resourceExists = await _context.Resources.AnyAsync(r => r.Id == dto.ResourceId);

            if (!resourceExists)
                return false;

            assignment.TaskId = dto.TaskId;
            assignment.ResourceId = dto.ResourceId;
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
    }
}