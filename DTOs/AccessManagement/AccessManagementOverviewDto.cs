namespace PlannerAPI.DTOs.AccessManagement
{
    public class AccessManagementOverviewDto
    {
        public bool IsGlobalAdmin { get; set; }

        public bool CanManageAccess { get; set; }

        public bool CanManageGlobalPermissions { get; set; }

        public List<AccessManagementProjectDto> Projects
            { get; set; } = new();

        public List<AccessManagementUserDto> Users
            { get; set; } = new();
    }

    public class AccessManagementProjectDto
    {
        public int Id { get; set; }

        public string Name { get; set; } =
            string.Empty;

        public string? ClientName { get; set; }

        public bool IsOwner { get; set; }

        public int MemberCount { get; set; }
    }

    public class AccessManagementUserDto
    {
        public string UserId { get; set; } =
            string.Empty;

        public string Email { get; set; } =
            string.Empty;

        public string? DisplayName { get; set; }

        public bool IsActive { get; set; }

        // Permission durable stockée sur AppUser.
        public bool CanCreateProjects { get; set; }

        // Droit effectif : Admin, permission durable,
        // propriétaire ou Manager actuel.
        public bool CanCreateProjectsEffectively
            { get; set; }

        public bool CanManageResources { get; set; }

        public bool IsGlobalAdmin { get; set; }

        public List<AccessManagementMembershipDto>
            Memberships { get; set; } = new();
    }

    public class AccessManagementMembershipDto
    {
        public int MemberId { get; set; }

        public int ProjectId { get; set; }

        public string ProjectName { get; set; } =
            string.Empty;

        public string Role { get; set; } =
            string.Empty;

        public bool IsOwner { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
