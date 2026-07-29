using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.ProjectCalendarExceptions;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectCalendarExceptionsController : ControllerBase
    {
        private readonly IProjectCalendarExceptionService _exceptionService;
        private readonly IProjectAuthorizationService _authorizationService;

        public ProjectCalendarExceptionsController(
            IProjectCalendarExceptionService exceptionService,
            IProjectAuthorizationService authorizationService)
        {
            _exceptionService = exceptionService;
            _authorizationService = authorizationService;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<IEnumerable<ProjectCalendarExceptionReadDto>>>
            GetByProjectId(int projectId)
        {
            if (!await _authorizationService.CanReadProjectAsync(projectId))
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            var exceptions =
                await _exceptionService.GetByProjectIdAsync(projectId);

            if (exceptions == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(exceptions);
        }

        [HttpPost("project/{projectId}")]
        public async Task<ActionResult<ProjectCalendarExceptionReadDto>>
            Create(
                int projectId,
                ProjectCalendarExceptionCreateDto dto)
        {
            if (!await _authorizationService.CanEditPlanningAsync(projectId))
                return Forbid();

            var exception =
                await _exceptionService.CreateAsync(projectId, dto);

            if (exception == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(exception);
        }

        [HttpPut("{exceptionId}")]
        public async Task<ActionResult<ProjectCalendarExceptionReadDto>>
            Update(
                int exceptionId,
                ProjectCalendarExceptionUpdateDto dto)
        {
            if (!await _authorizationService
                    .CanEditCalendarExceptionAsync(exceptionId))
            {
                return NotFound(
                    $"Exception avec l'id {exceptionId} introuvable ou accès insuffisant.");
            }

            try
            {
                var exception =
                    await _exceptionService.UpdateAsync(
                        exceptionId,
                        dto);

                if (exception == null)
                {
                    return NotFound(
                        $"Exception avec l'id {exceptionId} introuvable.");
                }

                return Ok(exception);
            }
            catch (InvalidOperationException error)
            {
                return Conflict(error.Message);
            }
        }

        [HttpDelete("{exceptionId}")]
        public async Task<IActionResult> Delete(int exceptionId)
        {
            if (!await _authorizationService
                    .CanEditCalendarExceptionAsync(exceptionId))
            {
                return NotFound(
                    $"Exception avec l'id {exceptionId} introuvable ou accès insuffisant.");
            }

            var deleted =
                await _exceptionService.DeleteAsync(exceptionId);

            if (!deleted)
                return NotFound($"Exception avec l'id {exceptionId} introuvable.");

            return NoContent();
        }
    }
}