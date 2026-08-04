using System.Data;
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
        private readonly IProjectAuthorizationService
            _projectAuthorization;
        private readonly UserManager<AppUser> _userManager;

        public ProjectMemberService(
            AppDbContext context,
            IProjectAuthorizationService projectAuthorization,
            UserManager<AppUser> userManager)
        {
            _context = context;
            _projectAuthorization = projectAuthorization;
            _userManager = userManager;
        }

        public async Task<IEnumerable<ProjectMemberReadDto>>
            GetMembersAsync(int projectId)
        {
            await EnsureCanManageMembersAsync(projectId);

            var project = await _context.Projects
                .AsNoTracking()
                .Include(project => project.Owner)
                .FirstOrDefaultAsync(
                    project => project.Id == projectId);

            if (project == null)
            {
                throw new KeyNotFoundException(
                    "Projet introuvable.");
            }

            var members = await _context.ProjectMembers
                .AsNoTracking()
                .Where(member =>
                    member.ProjectId == projectId)
                .Include(member => member.User)
                .OrderBy(member => member.User.Email)
                .ToListAsync();

            var result = new List<ProjectMemberReadDto>();

            // Le propriétaire appartient au projet même lorsqu'aucune
            // ligne ProjectMember n'a été créée pour lui.
            if (!string.IsNullOrWhiteSpace(
                    project.OwnerUserId))
            {
                var ownerMember = members.FirstOrDefault(
                    member =>
                        member.UserId ==
                        project.OwnerUserId);

                if (ownerMember != null)
                {
                    result.Add(
                        MapToReadDto(
                            ownerMember,
                            project.OwnerUserId));

                    members.Remove(ownerMember);
                }
                else if (project.Owner != null)
                {
                    result.Add(
                        MapOwnerToReadDto(
                            project.Id,
                            project.Owner));
                }
            }

            result.AddRange(
                members.Select(
                    member => MapToReadDto(
                        member,
                        project.OwnerUserId)));

            return result;
        }

        public async Task<ProjectMemberReadDto>
            AddMemberAsync(
                int projectId,
                ProjectMemberCreateDto dto)
        {
            await EnsureCanManageMembersAsync(projectId);

            var project = await _context.Projects
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    project => project.Id == projectId);

            if (project == null)
            {
                throw new KeyNotFoundException(
                    "Projet introuvable.");
            }

            var role = ParseProjectRole(dto.Role);
            var email = dto.Email.Trim();

            var user = await _userManager
                .FindByEmailAsync(email);

            if (user == null)
            {
                throw new InvalidOperationException(
                    "Aucun utilisateur Planner ne correspond " +
                    "à cet e-mail. Le compte doit être créé " +
                    "avant de pouvoir être ajouté au projet.");
            }

            if (!user.IsActive)
            {
                throw new InvalidOperationException(
                    "Cet utilisateur Planner est désactivé.");
            }

            if (user.Id == project.OwnerUserId)
            {
                throw new InvalidOperationException(
                    "Le propriétaire appartient déjà au projet " +
                    "et conserve obligatoirement le rôle Manager.");
            }

            var alreadyMember =
                await _context.ProjectMembers.AnyAsync(
                    member =>
                        member.ProjectId == projectId &&
                        member.UserId == user.Id);

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

            return MapToReadDto(
                member,
                project.OwnerUserId);
        }

        public async Task<ProjectMemberReadDto>
            UpdateMemberAsync(
                int projectId,
                int memberId,
                ProjectMemberUpdateDto dto)
        {
            await EnsureCanManageMembersAsync(projectId);

            var newRole = ParseProjectRole(dto.Role);

            await using var transaction =
                await _context.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable);

            var project = await _context.Projects
                .FirstOrDefaultAsync(
                    project => project.Id == projectId);

            if (project == null)
            {
                throw new KeyNotFoundException(
                    "Projet introuvable.");
            }

            var member = await _context.ProjectMembers
                .Include(projectMember =>
                    projectMember.User)
                .FirstOrDefaultAsync(
                    projectMember =>
                        projectMember.Id == memberId &&
                        projectMember.ProjectId ==
                        projectId);

            if (member == null)
            {
                throw new KeyNotFoundException(
                    "Membre du projet introuvable.");
            }

            if (member.UserId == project.OwnerUserId)
            {
                throw new InvalidOperationException(
                    "Le propriétaire du projet reste " +
                    "obligatoirement Manager.");
            }

            if (member.Role == ProjectRole.Manager &&
                newRole != ProjectRole.Manager)
            {
                await EnsureManagerWillRemainAsync(
                    project,
                    excludedMemberId: member.Id);
            }

            if (member.Role != newRole)
            {
                member.Role = newRole;
            }

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();

            return MapToReadDto(
                member,
                project.OwnerUserId);
        }

        public async Task RemoveMemberAsync(
            int projectId,
            int memberId)
        {
            await EnsureCanManageMembersAsync(projectId);

            await using var transaction =
                await _context.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable);

            var project = await _context.Projects
                .FirstOrDefaultAsync(
                    project => project.Id == projectId);

            if (project == null)
            {
                throw new KeyNotFoundException(
                    "Projet introuvable.");
            }

            var member = await _context.ProjectMembers
                .FirstOrDefaultAsync(
                    projectMember =>
                        projectMember.Id == memberId &&
                        projectMember.ProjectId ==
                        projectId);

            if (member == null)
            {
                throw new KeyNotFoundException(
                    "Membre du projet introuvable.");
            }

            if (member.UserId == project.OwnerUserId)
            {
                throw new InvalidOperationException(
                    "Le propriétaire du projet ne peut pas " +
                    "être retiré.");
            }

            if (member.Role == ProjectRole.Manager)
            {
                await EnsureManagerWillRemainAsync(
                    project,
                    excludedMemberId: member.Id);
            }

            _context.ProjectMembers.Remove(member);
            await _context.SaveChangesAsync();

            await transaction.CommitAsync();
        }

        private async Task EnsureCanManageMembersAsync(
            int projectId)
        {
            var projectExists = await _context.Projects
                .AsNoTracking()
                .AnyAsync(
                    project => project.Id == projectId);

            if (!projectExists)
            {
                throw new KeyNotFoundException(
                    "Projet introuvable.");
            }

            var canManage =
                await _projectAuthorization
                    .CanManageMembersAsync(projectId);

            if (!canManage)
            {
                throw new UnauthorizedAccessException(
                    "Seul un Manager du projet peut gérer " +
                    "ses membres.");
            }
        }

        private async Task EnsureManagerWillRemainAsync(
            Project project,
            int excludedMemberId)
        {
            // Le propriétaire est toujours un Manager effectif,
            // même s'il n'existe pas dans ProjectMembers.
            if (!string.IsNullOrWhiteSpace(
                    project.OwnerUserId))
            {
                return;
            }

            var anotherManagerExists =
                await _context.ProjectMembers
                    .AsNoTracking()
                    .AnyAsync(
                        member =>
                            member.ProjectId ==
                            project.Id &&
                            member.Id !=
                            excludedMemberId &&
                            member.Role ==
                            ProjectRole.Manager);

            if (!anotherManagerExists)
            {
                throw new InvalidOperationException(
                    "Le projet doit conserver au moins un " +
                    "Manager. Ajoute ou promeus un autre " +
                    "Manager avant cette opération.");
            }
        }

        private static ProjectRole ParseProjectRole(
            string role)
        {
            if (!Enum.TryParse<ProjectRole>(
                    role?.Trim(),
                    ignoreCase: true,
                    out var parsedRole) ||
                !Enum.IsDefined(parsedRole))
            {
                throw new InvalidOperationException(
                    "Rôle projet invalide. Valeurs autorisées : " +
                    "Manager, Lead, Technician, Viewer.");
            }

            return parsedRole;
        }

        private static ProjectMemberReadDto
            MapOwnerToReadDto(
                int projectId,
                AppUser owner)
        {
            return new ProjectMemberReadDto
            {
                // 0 signifie que le propriétaire n'est pas
                // matérialisé par une ligne ProjectMember.
                Id = 0,
                ProjectId = projectId,
                UserId = owner.Id,
                Email = owner.Email ?? string.Empty,
                DisplayName = owner.DisplayName,
                Role = ProjectRole.Manager.ToString(),
                IsOwner = true,
                CreatedAt = owner.CreatedAt
            };
        }

        private static ProjectMemberReadDto MapToReadDto(
            ProjectMember member,
            string? ownerUserId)
        {
            var isOwner =
                member.UserId == ownerUserId;

            return new ProjectMemberReadDto
            {
                Id = member.Id,
                ProjectId = member.ProjectId,
                UserId = member.UserId,
                Email = member.User.Email ??
                    string.Empty,
                DisplayName =
                    member.User.DisplayName,
                Role = isOwner
                    ? ProjectRole.Manager.ToString()
                    : member.Role.ToString(),
                IsOwner = isOwner,
                CreatedAt = member.CreatedAt
            };
        }
    }
}
