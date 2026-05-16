namespace PlannerAPI.DTOs.Resources
{
    public class ResourceGroupMemberReadDto
    {
        public int ResourceId { get; set; }

        public string ResourceName { get; set; } = string.Empty;

        public string ResourceType { get; set; } = string.Empty;
    }
}