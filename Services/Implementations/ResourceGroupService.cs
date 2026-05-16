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
            return await _context.ResourceGroups
                .Include(g => g.Members)
                    .ThenInclude(m => m.Resource)
                .Select(g => new ResourceGroupReadDto
                {
                    Id = g.Id,
                    Name = g.Name,
                    Description = g.Description,

                    Members = g.Members.Select(m => new ResourceGroupMemberReadDto
                    {
                        ResourceId = m.ResourceId,
                        ResourceName = m.Resource!.Name,
                        ResourceType = m.Resource.Type
                    }).ToList()
                })
                .ToListAsync();
        }

        public async Task<ResourceGroupReadDto?> GetByIdAsync(int id)
        {
            var group = await _context.ResourceGroups
                .Include(g => g.Members)
                    .ThenInclude(m => m.Resource)
                .FirstOrDefaultAsync(g => g.Id == id);

            if (group == null)
                return null;

            return new ResourceGroupReadDto
            {
                Id = group.Id,
                Name = group.Name,
                Description = group.Description,

                Members = group.Members.Select(m => new ResourceGroupMemberReadDto
                {
                    ResourceId = m.ResourceId,
                    ResourceName = m.Resource!.Name,
                    ResourceType = m.Resource.Type
                }).ToList()
            };
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

            return new ResourceGroupReadDto
            {
                Id = group.Id,
                Name = group.Name,
                Description = group.Description
            };
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
                    m.ResourceId == dto.ResourceId);

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
                    m.ResourceId == resourceId);

            if (member == null)
                return false;

            _context.ResourceGroupMembers.Remove(member);

            await _context.SaveChangesAsync();

            return true;
        }
    }
}