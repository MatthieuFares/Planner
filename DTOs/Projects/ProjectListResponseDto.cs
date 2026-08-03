namespace PlannerAPI.DTOs.Projects
{
    public class ProjectListResponseDto
    {
        public bool CanCreateProjects { get; set; }

        public bool CanImportProjects { get; set; }

        public List<ProjectListItemDto> Projects { get; set; } = new();
    }
}
