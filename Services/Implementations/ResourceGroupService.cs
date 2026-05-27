using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ResourceGroupService : IResourceGroupService
    {
        private readonly AppDbContext _context;

        public ResourceGroupService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<ResourceGroupReadDto>> GetAllAsync()
        {
            var groups = await _context.ResourceGroups
                .Include(g => g.Members)
                    .ThenInclude(m => m.Resource)
                .OrderBy(g => g.Name)
                .ToListAsync();

            return groups.Select(MapToReadDto);
        }

        public async Task<ResourceGroupReadDto?> GetByIdAsync(int id)
        {
            var group = await _context.ResourceGroups
                .Include(g => g.Members)
                    .ThenInclude(m => m.Resource)
                .FirstOrDefaultAsync(g => g.Id == id);

            if (group == null)
                return null;

            return MapToReadDto(group);
        }

        public async Task<IEnumerable<ResourceGroupMemberReadDto>> GetMembersAsync(int groupId)
        {
            var members = await _context.ResourceGroupMembers
                .Include(m => m.Resource)
                .Where(m => m.ResourceGroupId == groupId)
                .OrderBy(m => m.Resource!.Name)
                .ToListAsync();

            return members.Select(MapMemberToReadDto);
        }

        public async Task<ResourceGroupReadDto> CreateAsync(ResourceGroupCreateDto dto)
        {
            var group = new ResourceGroup
            {
                Name = dto.Name,
                Description = dto.Description
            };

            _context.ResourceGroups.Add(group);

            await _context.SaveChangesAsync();

            return MapToReadDto(group);
        }

        public async Task<bool> UpdateAsync(int id, ResourceGroupUpdateDto dto)
        {
            var group = await _context.ResourceGroups.FindAsync(id);

            if (group == null)
                return false;

            group.Name = dto.Name;
            group.Description = dto.Description;

            await _context.SaveChangesAsync();

            return true;
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var group = await _context.ResourceGroups
                .Include(g => g.Members)
                .FirstOrDefaultAsync(g => g.Id == id);

            if (group == null)
                return false;

            if (group.Members.Any())
            {
                throw new InvalidOperationException(
                    "Impossible de supprimer ce groupe : retire d’abord ses membres."
                );
            }

            _context.ResourceGroups.Remove(group);

            await _context.SaveChangesAsync();

            return true;
        }

        public async Task<bool> AddMemberAsync(ResourceGroupMemberCreateDto dto)
        {
            var groupExists = await _context.ResourceGroups
                .AnyAsync(g => g.Id == dto.ResourceGroupId);

            if (!groupExists)
                return false;

            var resourceExists = await _context.Resources
                .AnyAsync(r => r.Id == dto.ResourceId);

            if (!resourceExists)
                return false;

            var alreadyExists = await _context.ResourceGroupMembers
                .AnyAsync(m =>
                    m.ResourceGroupId == dto.ResourceGroupId &&
                    m.ResourceId == dto.ResourceId
                );

            if (alreadyExists)
                return false;

            var member = new ResourceGroupMember
            {
                ResourceGroupId = dto.ResourceGroupId,
                ResourceId = dto.ResourceId
            };

            _context.ResourceGroupMembers.Add(member);

            await _context.SaveChangesAsync();

            return true;
        }

        public async Task<bool> RemoveMemberAsync(int groupId, int resourceId)
        {
            var member = await _context.ResourceGroupMembers
                .FirstOrDefaultAsync(m =>
                    m.ResourceGroupId == groupId &&
                    m.ResourceId == resourceId
                );

            if (member == null)
                return false;

            _context.ResourceGroupMembers.Remove(member);

            await _context.SaveChangesAsync();

            return true;
        }

        private static ResourceGroupReadDto MapToReadDto(ResourceGroup group)
        {
            return new ResourceGroupReadDto
            {
                Id = group.Id,
                Name = group.Name,
                Description = group.Description,
                Members = group.Members
                    .Where(m => m.Resource != null)
                    .Select(MapMemberToReadDto)
                    .ToList()
            };
        }

        private static ResourceGroupMemberReadDto MapMemberToReadDto(ResourceGroupMember member)
        {
            return new ResourceGroupMemberReadDto
            {
                Id = member.Id,
                ResourceGroupId = member.ResourceGroupId,
                ResourceId = member.ResourceId,
                ResourceName = member.Resource?.Name ?? string.Empty,
                ResourceType = member.Resource?.Type ?? string.Empty,
                CapacityHoursPerWeek = member.Resource?.CapacityHoursPerWeek ?? 0,
                CostPerHour = member.Resource?.CostPerHour ?? 0
            };
        }
    }
}