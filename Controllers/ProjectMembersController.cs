using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.ProjectMembers;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/projects/{projectId:int}/members")]
    public class ProjectMembersController : ControllerBase
    {
        private readonly IProjectMemberService _projectMemberService;

        public ProjectMembersController(
            IProjectMemberService projectMemberService)
        {
            _projectMemberService = projectMemberService;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<ProjectMemberReadDto>>>
            GetMembers(int projectId)
        {
            try
            {
                return Ok(
                    await _projectMemberService.GetMembersAsync(projectId));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ex.Message);
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
        }

        [HttpPost]
        public async Task<ActionResult<ProjectMemberReadDto>>
            AddMember(
                int projectId,
                ProjectMemberCreateDto dto)
        {
            try
            {
                var member =
                    await _projectMemberService.AddMemberAsync(
                        projectId,
                        dto);

                return CreatedAtAction(
                    nameof(GetMembers),
                    new { projectId },
                    member);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ex.Message);
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPut("{memberId:int}")]
        public async Task<ActionResult<ProjectMemberReadDto>>
            UpdateMember(
                int projectId,
                int memberId,
                ProjectMemberUpdateDto dto)
        {
            try
            {
                return Ok(
                    await _projectMemberService.UpdateMemberAsync(
                        projectId,
                        memberId,
                        dto));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ex.Message);
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpDelete("{memberId:int}")]
        public async Task<IActionResult>
            RemoveMember(
                int projectId,
                int memberId)
        {
            try
            {
                await _projectMemberService.RemoveMemberAsync(
                    projectId,
                    memberId);

                return NoContent();
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ex.Message);
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}
