namespace PlannerAPI.DTOs.ProjectMembers
{
    public class ProjectMemberReadDto
    {
        public int Id { get; set; }
        public int ProjectId { get; set; }
        public string UserId { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? DisplayName { get; set; }
        public string Role { get; set; } = string.Empty;
        public bool IsOwner { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
