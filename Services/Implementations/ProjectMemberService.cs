using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.ProjectMembers;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ProjectMemberService : IProjectMemberService
    {
        private readonly AppDbContext _context;
        private readonly ICurrentUserService _currentUser;
        private readonly UserManager<AppUser> _userManager;

        public ProjectMemberService(
            AppDbContext context,
            ICurrentUserService currentUser,
            UserManager<AppUser> userManager)
        {
            _context = context;
            _currentUser = currentUser;
            _userManager = userManager;
        }

        public async Task<IEnumerable<ProjectMemberReadDto>> GetMembersAsync(
            int projectId)
        {
            await EnsureCanManageMembersAsync(projectId);

            var project = await _context.Projects
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == projectId);

            if (project == null)
                throw new KeyNotFoundException("Projet introuvable.");

            var members = await _context.ProjectMembers
                .AsNoTracking()
                .Where(pm => pm.ProjectId == projectId)
                .Include(pm => pm.User)
                .OrderBy(pm => pm.User.Email)
                .ToListAsync();

            return members.Select(member =>
                MapToReadDto(member, project.OwnerUserId));
        }

        public async Task<ProjectMemberReadDto> AddMemberAsync(
            int projectId,
            ProjectMemberCreateDto dto)
        {
            await EnsureCanManageMembersAsync(projectId);

            var project = await _context.Projects
                .FirstOrDefaultAsync(p => p.Id == projectId);

            if (project == null)
                throw new KeyNotFoundException("Projet introuvable.");

            var role = ParseProjectRole(dto.Role);

            var user = await _userManager.FindByEmailAsync(dto.Email.Trim());

            if (user == null)
            {
                throw new InvalidOperationException(
                    "Aucun utilisateur Planner ne correspond à cet e-mail. " +
                    "Le compte doit être créé avant de pouvoir être ajouté au projet.");
            }

            if (!user.IsActive)
            {
                throw new InvalidOperationException(
                    "Cet utilisateur Planner est désactivé.");
            }

            var alreadyMember = await _context.ProjectMembers
                .AnyAsync(pm =>
                    pm.ProjectId == projectId &&
                    pm.UserId == user.Id);

            if (alreadyMember)
            {
                throw new InvalidOperationException(
                    "Cet utilisateur est déjà membre du projet.");
            }

            var member = new ProjectMember
            {
                ProjectId = projectId,
                UserId = user.Id,
                Role = role,
                CreatedAt = DateTime.UtcNow
            };

            _context.ProjectMembers.Add(member);
            await _context.SaveChangesAsync();

            member.User = user;

            return MapToReadDto(member, project.OwnerUserId);
        }

        public async Task<ProjectMemberReadDto> UpdateMemberAsync(
            int projectId,
            int memberId,
            ProjectMemberUpdateDto dto)
        {
            await EnsureCanManageMembersAsync(projectId);

            var project = await _context.Projects
                .FirstOrDefaultAsync(p => p.Id == projectId);

            if (project == null)
                throw new KeyNotFoundException("Projet introuvable.");

            var member = await _context.ProjectMembers
                .Include(pm => pm.User)
                .FirstOrDefaultAsync(pm =>
                    pm.Id == memberId &&
                    pm.ProjectId == projectId);

            if (member == null)
                throw new KeyNotFoundException("Membre du projet introuvable.");

            if (member.UserId == project.OwnerUserId)
            {
                throw new InvalidOperationException(
                    "Le propriétaire du projet reste obligatoirement Manager.");
            }

            member.Role = ParseProjectRole(dto.Role);

            await _context.SaveChangesAsync();

            return MapToReadDto(member, project.OwnerUserId);
        }

        public async Task RemoveMemberAsync(
            int projectId,
            int memberId)
        {
            await EnsureCanManageMembersAsync(projectId);

            var project = await _context.Projects
                .FirstOrDefaultAsync(p => p.Id == projectId);

            if (project == null)
                throw new KeyNotFoundException("Projet introuvable.");

            var member = await _context.ProjectMembers
                .FirstOrDefaultAsync(pm =>
                    pm.Id == memberId &&
                    pm.ProjectId == projectId);

            if (member == null)
                throw new KeyNotFoundException("Membre du projet introuvable.");

            if (member.UserId == project.OwnerUserId)
            {
                throw new InvalidOperationException(
                    "Le propriétaire du projet ne peut pas être retiré.");
            }

            _context.ProjectMembers.Remove(member);
            await _context.SaveChangesAsync();
        }

        private async Task EnsureCanManageMembersAsync(int projectId)
        {
            var projectExists = await _context.Projects
                .AsNoTracking()
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                throw new KeyNotFoundException("Projet introuvable.");

            if (_currentUser.IsGlobalAdmin)
                return;

            var userId = _currentUser.UserId;

            var canManage = await _context.Projects
                .AsNoTracking()
                .AnyAsync(p =>
                    p.Id == projectId &&
                    (
                        p.OwnerUserId == userId ||
                        p.Members.Any(m =>
                            m.UserId == userId &&
                            m.Role == ProjectRole.Manager)
                    ));

            if (!canManage)
            {
                throw new UnauthorizedAccessException(
                    "Seul un Manager du projet peut gérer ses membres.");
            }
        }

        private static ProjectRole ParseProjectRole(string role)
        {
            if (!Enum.TryParse<ProjectRole>(
                    role?.Trim(),
                    true,
                    out var parsedRole) ||
                !Enum.IsDefined(parsedRole))
            {
                throw new InvalidOperationException(
                    "Rôle projet invalide. Valeurs autorisées : " +
                    "Manager, Lead, Technician, Viewer.");
            }

            return parsedRole;
        }

        private static ProjectMemberReadDto MapToReadDto(
            ProjectMember member,
            string? ownerUserId)
        {
            return new ProjectMemberReadDto
            {
                Id = member.Id,
                ProjectId = member.ProjectId,
                UserId = member.UserId,
                Email = member.User.Email ?? string.Empty,
                DisplayName = member.User.DisplayName,
                Role = member.Role.ToString(),
                IsOwner = member.UserId == ownerUserId,
                CreatedAt = member.CreatedAt
            };
        }
    }
}
