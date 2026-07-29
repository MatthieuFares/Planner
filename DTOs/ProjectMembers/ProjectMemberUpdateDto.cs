using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.ProjectMembers
{
    public class ProjectMemberUpdateDto
    {
        [Required]
        public string Role { get; set; } = string.Empty;
    }
}
