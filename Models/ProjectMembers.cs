using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class ProjectMember
    {
        public int Id { get; set; }

        public int ProjectId { get; set; }

        public Project Project { get; set; } = null!;

        [Required]
        public string UserId { get; set; } = string.Empty;

        public AppUser User { get; set; } = null!;

        public ProjectRole Role { get; set; } = ProjectRole.Viewer;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}