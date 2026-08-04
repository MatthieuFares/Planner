using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.AccessManagement;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class AccessManagementService :
        IAccessManagementService
    {
        private readonly AppDbContext _context;
        private readonly ICurrentUserService _currentUser;
        private readonly UserManager<AppUser> _userManager;

        public AccessManagementService(
            AppDbContext context,
            ICurrentUserService currentUser,
            UserManager<AppUser> userManager)
        {
            _context = context;
            _currentUser = currentUser;
            _userManager = userManager;
        }

        public async Task<AccessManagementOverviewDto>
            GetOverviewAsync()
        {
            var isGlobalAdmin =
                _currentUser.IsGlobalAdmin;
            var currentUserId =
                _currentUser.UserId;

            var projectQuery = _context.Projects
                .AsNoTracking()
                .AsQueryable();

            if (!isGlobalAdmin)
            {
                projectQuery = projectQuery.Where(
                    project =>
                        project.OwnerUserId ==
                            currentUserId ||
                        project.Members.Any(member =>
                            member.UserId ==
                                currentUserId &&
                            member.Role ==
                                ProjectRole.Manager));
            }

            var projectRows = await projectQuery
                .OrderBy(project => project.Name)
                .Select(project => new
                {
                    project.Id,
                    project.Name,
                    project.ClientName,
                    project.OwnerUserId
                })
                .ToListAsync();

            if (!isGlobalAdmin &&
                projectRows.Count == 0)
            {
                throw new UnauthorizedAccessException(
                    "Aucun projet administrable n'est "
                    + "disponible pour cet utilisateur.");
            }

            var projectIds = projectRows
                .Select(project => project.Id)
                .ToList();

            var memberRows =
                projectIds.Count == 0
                    ? new List<ProjectMember>()
                    : await _context.ProjectMembers
                        .AsNoTracking()
                        .Include(member =>
                            member.User)
                        .Where(member =>
                            projectIds.Contains(
                                member.ProjectId))
                        .ToListAsync();

            var projectNameById = projectRows
                .ToDictionary(
                    project => project.Id,
                    project => project.Name);

            var ownerIds = projectRows
                .Where(project =>
                    !string.IsNullOrWhiteSpace(
                        project.OwnerUserId))
                .Select(project =>
                    project.OwnerUserId!)
                .Distinct()
                .ToList();

            var owners = ownerIds.Count == 0
                ? new List<AppUser>()
                : await _context.Users
                    .AsNoTracking()
                    .Where(user =>
                        ownerIds.Contains(user.Id))
                    .ToListAsync();

            var ownerById = owners.ToDictionary(
                owner => owner.Id);

            var membershipsByUser =
                new Dictionary<
                    string,
                    List<AccessManagementMembershipDto>>();

            var uniqueMembershipKeys =
                new HashSet<string>(
                    StringComparer.Ordinal);

            foreach (var project in projectRows)
            {
                if (string.IsNullOrWhiteSpace(
                        project.OwnerUserId) ||
                    !ownerById.ContainsKey(
                        project.OwnerUserId))
                {
                    continue;
                }

                var ownerMemberRow =
                    memberRows.FirstOrDefault(member =>
                        member.ProjectId ==
                            project.Id &&
                        member.UserId ==
                            project.OwnerUserId);

                AddMembership(
                    membershipsByUser,
                    uniqueMembershipKeys,
                    project.OwnerUserId,
                    new AccessManagementMembershipDto
                    {
                        MemberId =
                            ownerMemberRow?.Id ?? 0,
                        ProjectId = project.Id,
                        ProjectName = project.Name,
                        Role =
                            ProjectRole.Manager
                                .ToString(),
                        IsOwner = true,
                        CreatedAt =
                            ownerMemberRow?.CreatedAt ??
                            ownerById[
                                project.OwnerUserId]
                                .CreatedAt
                    });
            }

            foreach (var member in memberRows)
            {
                var project = projectRows
                    .First(projectRow =>
                        projectRow.Id ==
                            member.ProjectId);

                if (member.UserId ==
                    project.OwnerUserId)
                {
                    continue;
                }

                AddMembership(
                    membershipsByUser,
                    uniqueMembershipKeys,
                    member.UserId,
                    new AccessManagementMembershipDto
                    {
                        MemberId = member.Id,
                        ProjectId = member.ProjectId,
                        ProjectName =
                            projectNameById[
                                member.ProjectId],
                        Role =
                            member.Role.ToString(),
                        IsOwner = false,
                        CreatedAt =
                            member.CreatedAt
                    });
            }

            List<AppUser> users;

            if (isGlobalAdmin)
            {
                users = await _context.Users
                    .AsNoTracking()
                    .OrderBy(user =>
                        user.DisplayName ??
                        user.Email)
                    .ToListAsync();
            }
            else
            {
                var visibleUserIds =
                    membershipsByUser.Keys
                        .ToList();

                users = visibleUserIds.Count == 0
                    ? new List<AppUser>()
                    : await _context.Users
                        .AsNoTracking()
                        .Where(user =>
                            visibleUserIds.Contains(
                                user.Id))
                        .OrderBy(user =>
                            user.DisplayName ??
                            user.Email)
                        .ToListAsync();
            }

            var adminRoleId = await _context.Roles
                .AsNoTracking()
                .Where(role =>
                    role.NormalizedName == "ADMIN")
                .Select(role => role.Id)
                .FirstOrDefaultAsync();

            var adminUserIds =
                string.IsNullOrWhiteSpace(
                    adminRoleId)
                    ? new HashSet<string>()
                    : (await _context.UserRoles
                        .AsNoTracking()
                        .Where(userRole =>
                            userRole.RoleId ==
                                adminRoleId)
                        .Select(userRole =>
                            userRole.UserId)
                        .ToListAsync())
                        .ToHashSet();

            var projectDtos = projectRows
                .Select(project =>
                {
                    var memberCount =
                        membershipsByUser.Values
                            .SelectMany(value => value)
                            .Count(membership =>
                                membership.ProjectId ==
                                    project.Id);

                    return new AccessManagementProjectDto
                    {
                        Id = project.Id,
                        Name = project.Name,
                        ClientName =
                            project.ClientName,
                        IsOwner =
                            project.OwnerUserId ==
                                currentUserId,
                        MemberCount =
                            memberCount
                    };
                })
                .ToList();

            var userDtos = users
                .Select(user =>
                {
                    membershipsByUser.TryGetValue(
                        user.Id,
                        out var memberships);

                    memberships ??=
                        new List<
                            AccessManagementMembershipDto>();

                    var userIsAdmin =
                        adminUserIds.Contains(user.Id);

                    var effectiveCreation =
                        userIsAdmin ||
                        user.CanCreateProjects ||
                        memberships.Any(
                            membership =>
                                membership.IsOwner ||
                                membership.Role ==
                                    ProjectRole.Manager
                                        .ToString());

                    return new AccessManagementUserDto
                    {
                        UserId = user.Id,
                        Email =
                            user.Email ??
                            string.Empty,
                        DisplayName =
                            user.DisplayName,
                        IsActive =
                            user.IsActive,
                        CanCreateProjects =
                            user.CanCreateProjects,
                        CanCreateProjectsEffectively =
                            effectiveCreation,
                        CanManageResources =
                            user.CanManageResources,
                        IsGlobalAdmin =
                            userIsAdmin,
                        Memberships =
                            memberships
                                .OrderBy(membership =>
                                    membership.ProjectName)
                                .ToList()
                    };
                })
                .OrderBy(user =>
                    string.IsNullOrWhiteSpace(
                        user.DisplayName)
                        ? user.Email
                        : user.DisplayName)
                .ToList();

            return new AccessManagementOverviewDto
            {
                IsGlobalAdmin =
                    isGlobalAdmin,
                CanManageAccess = true,
                CanManageGlobalPermissions =
                    isGlobalAdmin,
                Projects = projectDtos,
                Users = userDtos
            };
        }

        public async Task UpdateGlobalPermissionsAsync(
            string userId,
            GlobalUserPermissionsUpdateDto dto)
        {
            if (!_currentUser.IsGlobalAdmin)
            {
                throw new UnauthorizedAccessException(
                    "Seul un Admin global peut modifier "
                    + "les permissions générales.");
            }

            var user = await _userManager
                .FindByIdAsync(userId);

            if (user == null)
            {
                throw new KeyNotFoundException(
                    "Utilisateur Planner introuvable.");
            }

            var isSelf =
                user.Id == _currentUser.UserId;

            if (isSelf && !dto.IsActive)
            {
                throw new InvalidOperationException(
                    "Un Admin global ne peut pas "
                    + "désactiver son propre compte.");
            }

            if (isSelf && !dto.IsGlobalAdmin)
            {
                throw new InvalidOperationException(
                    "Un Admin global ne peut pas retirer "
                    + "son propre rôle Admin.");
            }

            await using var transaction =
                await _context.Database
                    .BeginTransactionAsync();

            try
            {
                user.IsActive =
                    dto.IsActive;
                user.CanCreateProjects =
                    dto.CanCreateProjects;
                user.CanManageResources =
                    dto.CanManageResources;

                var updateResult =
                    await _userManager
                        .UpdateAsync(user);

                EnsureIdentityResult(
                    updateResult,
                    "mettre à jour les permissions");

                var currentlyAdmin =
                    await _userManager
                        .IsInRoleAsync(
                            user,
                            "Admin");

                if (dto.IsGlobalAdmin &&
                    !currentlyAdmin)
                {
                    var addResult =
                        await _userManager
                            .AddToRoleAsync(
                                user,
                                "Admin");

                    EnsureIdentityResult(
                        addResult,
                        "attribuer le rôle Admin");
                }
                else if (!dto.IsGlobalAdmin &&
                         currentlyAdmin)
                {
                    var removeResult =
                        await _userManager
                            .RemoveFromRoleAsync(
                                user,
                                "Admin");

                    EnsureIdentityResult(
                        removeResult,
                        "retirer le rôle Admin");
                }

                await transaction.CommitAsync();
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        private static void AddMembership(
            IDictionary<
                string,
                List<AccessManagementMembershipDto>>
                    membershipsByUser,
            ISet<string> uniqueMembershipKeys,
            string userId,
            AccessManagementMembershipDto membership)
        {
            var key =
                $"{membership.ProjectId}:{userId}";

            if (!uniqueMembershipKeys.Add(key))
                return;

            if (!membershipsByUser.TryGetValue(
                    userId,
                    out var memberships))
            {
                memberships =
                    new List<
                        AccessManagementMembershipDto>();

                membershipsByUser[userId] =
                    memberships;
            }

            memberships.Add(membership);
        }

        private static void EnsureIdentityResult(
            IdentityResult result,
            string operation)
        {
            if (result.Succeeded)
                return;

            var errors = string.Join(
                " | ",
                result.Errors.Select(error =>
                    $"{error.Code}: "
                    + error.Description));

            throw new InvalidOperationException(
                $"Impossible de {operation} : {errors}");
        }
    }
}
