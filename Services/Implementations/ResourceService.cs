using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ResourceService : IResourceService
    {
        private readonly AppDbContext _context;

        public ResourceService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<ResourceReadDto>> GetAllAsync()
        {
            return await _context.Resources
                .Select(r => new ResourceReadDto
                {
                    Id = r.Id,
                    Name = r.Name,
                    Type = r.Type,
                    CapacityHoursPerWeek = r.CapacityHoursPerWeek,
                    CostPerHour = r.CostPerHour
                })
                .ToListAsync();
        }

        public async Task<ResourceReadDto?> GetByIdAsync(int id)
        {
            var resource = await _context.Resources.FindAsync(id);

            if (resource == null)
                return null;

            return new ResourceReadDto
            {
                Id = resource.Id,
                Name = resource.Name,
                Type = resource.Type,
                CapacityHoursPerWeek = resource.CapacityHoursPerWeek,
                CostPerHour = resource.CostPerHour
            };
        }

        public async Task<ResourceReadDto> CreateAsync(ResourceCreateDto dto)
        {
            var resource = new Resource
            {
                Name = dto.Name,
                Type = dto.Type,
                CapacityHoursPerWeek = dto.CapacityHoursPerWeek,
                CostPerHour = dto.CostPerHour
            };

            _context.Resources.Add(resource);
            await _context.SaveChangesAsync();

            return new ResourceReadDto
            {
                Id = resource.Id,
                Name = resource.Name,
                Type = resource.Type,
                CapacityHoursPerWeek = resource.CapacityHoursPerWeek,
                CostPerHour = resource.CostPerHour
            };
        }

        public async Task<bool> UpdateAsync(int id, ResourceUpdateDto dto)
        {
            var resource = await _context.Resources.FindAsync(id);

            if (resource == null)
                return false;

            resource.Name = dto.Name;
            resource.Type = dto.Type;
            resource.CapacityHoursPerWeek = dto.CapacityHoursPerWeek;
            resource.CostPerHour = dto.CostPerHour;

            await _context.SaveChangesAsync();

            return true;
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var resource = await _context.Resources.FindAsync(id);

            if (resource == null)
                return false;

            _context.Resources.Remove(resource);

            await _context.SaveChangesAsync();

            return true;
        }
    }
}