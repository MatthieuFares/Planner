using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.DTOs.PlanningVersions;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class PlanningVersionsController : ControllerBase
    {
        private readonly IPlanningVersionService _planningVersionService;
        private readonly IProjectAuthorizationService _authorizationService;

        public PlanningVersionsController(
            IPlanningVersionService planningVersionService,
            IProjectAuthorizationService authorizationService)
        {
            _planningVersionService = planningVersionService;
            _authorizationService = authorizationService;
        }

        /// <summary>
        /// Crée une nouvelle version complète du planning courant.
        /// </summary>
        [HttpPost("project/{projectId:int}")]
        [ProducesResponseType(
            typeof(PlanningVersionSummaryResponse),
            StatusCodes.Status201Created)]
        [ProducesResponseType(
            StatusCodes.Status400BadRequest)]
        [ProducesResponseType(
            StatusCodes.Status403Forbidden)]
        [ProducesResponseType(
            StatusCodes.Status404NotFound)]
        [ProducesResponseType(
            StatusCodes.Status409Conflict)]
        public async Task<ActionResult<PlanningVersionSummaryResponse>>
            Create(
                int projectId,
                [FromBody] CreatePlanningVersionRequest request)
        {
            if (!await _authorizationService
                    .CanEditPlanningAsync(projectId))
            {
                return Forbid();
            }

            try
            {
                var version =
                    await _planningVersionService.CreateAsync(
                        projectId,
                        request);

                return CreatedAtAction(
                    nameof(GetById),
                    new { versionId = version.Id },
                    version);
            }
            catch (ArgumentException exception)
            {
                return BadRequest(new
                {
                    message = exception.Message
                });
            }
            catch (KeyNotFoundException exception)
            {
                return NotFound(new
                {
                    message = exception.Message
                });
            }
            catch (DbUpdateException exception)
            {
                return Conflict(new
                {
                    message =
                        "La version n'a pas pu être enregistrée. " +
                        "Une autre création a peut-être été effectuée " +
                        "simultanément.",
                    detail = exception.InnerException?.Message
                });
            }
        }

        /// <summary>
        /// Retourne l'historique léger des versions d'un projet.
        /// </summary>
        [HttpGet("project/{projectId:int}")]
        [ProducesResponseType(
            typeof(List<PlanningVersionSummaryResponse>),
            StatusCodes.Status200OK)]
        [ProducesResponseType(
            StatusCodes.Status404NotFound)]
        public async Task<
            ActionResult<List<PlanningVersionSummaryResponse>>>
            GetByProject(int projectId)
        {
            if (!await _authorizationService
                    .CanReadProjectAsync(projectId))
            {
                return NotFound(new
                {
                    message =
                        $"Le projet {projectId} est introuvable."
                });
            }

            var versions =
                await _planningVersionService.GetByProjectAsync(
                    projectId);

            return Ok(versions);
        }

        /// <summary>
        /// Compare une version enregistrée avec le planning courant.
        /// </summary>
        [HttpGet("{versionId:int}/compare-current")]
        [ProducesResponseType(
            typeof(PlanningVersionComparisonResponse),
            StatusCodes.Status200OK)]
        [ProducesResponseType(
            StatusCodes.Status404NotFound)]
        public async Task<
            ActionResult<PlanningVersionComparisonResponse>>
            CompareWithCurrent(int versionId)
        {
            if (!await _authorizationService
                    .CanReadPlanningVersionAsync(versionId))
            {
                return NotFound(new
                {
                    message =
                        $"La version {versionId} est introuvable."
                });
            }

            var comparison =
                await _planningVersionService
                    .CompareWithCurrentAsync(versionId);

            if (comparison is null)
            {
                return NotFound(new
                {
                    message =
                        $"La version {versionId} est introuvable."
                });
            }

            return Ok(comparison);
        }

        /// <summary>
        /// Restaure le planning courant à partir d'une version enregistrée.
        /// Une version de sécurité peut être créée automatiquement avant
        /// toute modification destructive.
        /// </summary>
        [HttpPost("{versionId:int}/restore")]
        [ProducesResponseType(
            typeof(RestorePlanningVersionResponse),
            StatusCodes.Status200OK)]
        [ProducesResponseType(
            StatusCodes.Status400BadRequest)]
        [ProducesResponseType(
            StatusCodes.Status404NotFound)]
        [ProducesResponseType(
            StatusCodes.Status409Conflict)]
        public async Task<ActionResult<RestorePlanningVersionResponse>>
            Restore(
                int versionId,
                [FromBody] RestorePlanningVersionRequest request)
        {
            if (!await _authorizationService
                    .CanEditPlanningVersionAsync(versionId))
            {
                return NotFound(new
                {
                    message =
                        $"La version {versionId} est introuvable " +
                        "ou l'accès est insuffisant."
                });
            }

            try
            {
                var result =
                    await _planningVersionService.RestoreAsync(
                        versionId,
                        request);

                if (result is null)
                {
                    return NotFound(new
                    {
                        message =
                            $"La version {versionId} est introuvable."
                    });
                }

                return Ok(result);
            }
            catch (ArgumentException exception)
            {
                return BadRequest(new
                {
                    message = exception.Message
                });
            }
            catch (InvalidOperationException exception)
            {
                return Conflict(new
                {
                    message = exception.Message
                });
            }
            catch (DbUpdateException exception)
            {
                return Conflict(new
                {
                    message =
                        "La restauration n'a pas pu être appliquée " +
                        "à cause d'une incohérence de données.",
                    detail = exception.InnerException?.Message
                });
            }
        }

        /// <summary>
        /// Retourne le snapshot complet d'une version.
        /// </summary>
        [HttpGet("{versionId:int}")]
        [ProducesResponseType(
            typeof(PlanningVersionDetailResponse),
            StatusCodes.Status200OK)]
        [ProducesResponseType(
            StatusCodes.Status404NotFound)]
        public async Task<ActionResult<PlanningVersionDetailResponse>>
            GetById(int versionId)
        {
            if (!await _authorizationService
                    .CanReadPlanningVersionAsync(versionId))
            {
                return NotFound(new
                {
                    message =
                        $"La version {versionId} est introuvable."
                });
            }

            var version =
                await _planningVersionService.GetByIdAsync(
                    versionId);

            if (version is null)
            {
                return NotFound(new
                {
                    message =
                        $"La version {versionId} est introuvable."
                });
            }

            return Ok(version);
        }

        /// <summary>
        /// Supprime définitivement une version enregistrée.
        /// </summary>
        [HttpDelete("{versionId:int}")]
        [ProducesResponseType(
            StatusCodes.Status204NoContent)]
        [ProducesResponseType(
            StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Delete(int versionId)
        {
            if (!await _authorizationService
                    .CanEditPlanningVersionAsync(versionId))
            {
                return NotFound(new
                {
                    message =
                        $"La version {versionId} est introuvable " +
                        "ou l'accès est insuffisant."
                });
            }

            var deleted =
                await _planningVersionService.DeleteAsync(
                    versionId);

            if (!deleted)
            {
                return NotFound(new
                {
                    message =
                        $"La version {versionId} est introuvable."
                });
            }

            return NoContent();
        }
    }
}