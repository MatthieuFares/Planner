using PlannerAPI.DTOs.ProjectMembers;

namespace PlannerAPI.Services.Interfaces
{
    public interface IProjectMemberService
    {
        Task<IEnumerable<ProjectMemberReadDto>> GetMembersAsync(int projectId);

        Task<ProjectMemberReadDto> AddMemberAsync(
            int projectId,
            ProjectMemberCreateDto dto);

        Task<ProjectMemberReadDto> UpdateMemberAsync(
            int projectId,
            int memberId,
            ProjectMemberUpdateDto dto);

        Task RemoveMemberAsync(int projectId, int memberId);
    }
}
