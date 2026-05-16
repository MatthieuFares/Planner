namespace PlannerAPI.DTOs.Resources
{
    public class ResourceGroupReadDto
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string? Description { get; set; }

        public List<ResourceGroupMemberReadDto> Members { get; set; } = new();
    }
}