namespace PlannerAPI.DTOs.AccessManagement
{
    public class GlobalUserPermissionsUpdateDto
    {
        public bool IsActive { get; set; }

        public bool CanCreateProjects { get; set; }

        public bool CanManageResources { get; set; }

        public bool IsGlobalAdmin { get; set; }
    }
}
