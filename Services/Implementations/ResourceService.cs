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

        private static readonly HashSet<string> AllowedResourceTypes = new(
            StringComparer.OrdinalIgnoreCase
        )
        {
            "Person",
            "Team",
            "Material"
        };

        public ResourceService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<ResourceReadDto>> GetAllAsync()
        {
            var resources = await _context.Resources
                .OrderBy(r => r.Name)
                .ToListAsync();

            return resources.Select(MapToReadDto);
        }

        public async Task<ResourceReadDto?> GetByIdAsync(int id)
        {
            var resource = await _context.Resources.FindAsync(id);

            if (resource == null)
                return null;

            return MapToReadDto(resource);
        }

        public async Task<ResourceReadDto> CreateAsync(ResourceCreateDto dto)
        {
            var type = NormalizeResourceType(dto.Type);

            var resource = new Resource
            {
                Name = dto.Name.Trim(),
                Type = type,
                CapacityHoursPerWeek = NormalizePositiveDecimal(dto.CapacityHoursPerWeek),
                CostPerHour = NormalizePositiveDecimal(dto.CostPerHour)
            };

            _context.Resources.Add(resource);

            await _context.SaveChangesAsync();

            return MapToReadDto(resource);
        }

        public async Task<ResourceReadDto?> UpdateAsync(int id, ResourceUpdateDto dto)
        {
            var resource = await _context.Resources.FindAsync(id);

            if (resource == null)
                return null;

            var type = NormalizeResourceType(dto.Type);

            resource.Name = dto.Name.Trim();
            resource.Type = type;
            resource.CapacityHoursPerWeek = NormalizePositiveDecimal(dto.CapacityHoursPerWeek);
            resource.CostPerHour = NormalizePositiveDecimal(dto.CostPerHour);

            await _context.SaveChangesAsync();

            return MapToReadDto(resource);
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var resource = await _context.Resources
                .Include(r => r.Assignments)
                .FirstOrDefaultAsync(r => r.Id == id);

            if (resource == null)
                return false;

            var hasAssignments = resource.Assignments.Any();

            if (hasAssignments)
            {
                throw new InvalidOperationException(
                    "Impossible de supprimer cette ressource : elle est utilisée dans une ou plusieurs assignations."
                );
            }

            var isGroupMember = await _context.ResourceGroupMembers
                .AnyAsync(member => member.ResourceId == id);

            if (isGroupMember)
            {
                throw new InvalidOperationException(
                    "Impossible de supprimer cette ressource : elle appartient à un ou plusieurs groupes."
                );
            }

            _context.Resources.Remove(resource);

            await _context.SaveChangesAsync();

            return true;
        }

        private static ResourceReadDto MapToReadDto(Resource resource)
        {
            return new ResourceReadDto
            {
                Id = resource.Id,
                Name = resource.Name,
                Type = resource.Type,
                CapacityHoursPerWeek = resource.CapacityHoursPerWeek,
                CostPerHour = resource.CostPerHour
            };
        }

        private static string NormalizeResourceType(string? type)
        {
            if (string.IsNullOrWhiteSpace(type))
            {
                throw new InvalidOperationException(
                    "Le type de ressource est obligatoire. Valeurs autorisées : Person, Team, Material."
                );
            }

            var normalized = type.Trim();

            if (!AllowedResourceTypes.Contains(normalized))
            {
                throw new InvalidOperationException(
                    "Type de ressource invalide. Valeurs autorisées : Person, Team, Material."
                );
            }

            return AllowedResourceTypes.First(t =>
                string.Equals(t, normalized, StringComparison.OrdinalIgnoreCase)
            );
        }

        private static decimal? NormalizePositiveDecimal(decimal? value)
        {
            if (!value.HasValue)
                return null;

            if (value.Value < 0)
            {
                throw new InvalidOperationException(
                    "Les valeurs numériques d'une ressource ne peuvent pas être négatives."
                );
            }

            return value.Value;
        }
    }
}