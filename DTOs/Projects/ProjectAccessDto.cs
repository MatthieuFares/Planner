namespace PlannerAPI.DTOs.Projects
{
    public class ProjectAccessDto
    {
        public int ProjectId { get; set; }

        public bool CanReadProject { get; set; }

        public bool CanEditPlanning { get; set; }

        public bool CanManageMembers { get; set; }

        public bool CanDeleteProject { get; set; }

        public bool CanCreateProjects { get; set; }

        public bool CanReadResourceCatalog { get; set; }

        public bool CanManageResourceCatalog { get; set; }

        public bool CanImportProjects { get; set; }
    }
}
