using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.DTOs.ProjectInterop;
using PlannerAPI.Services.Interfaces;
using PlannerAPI.Services.ProjectInterop;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectInteropController : ControllerBase
    {
        private static readonly HashSet<string> AllowedExtensions =
            new(StringComparer.OrdinalIgnoreCase)
            {
                ".xml",
                ".mspdi"
            };

        private const long MaxPreviewFileSizeBytes = 25 * 1024 * 1024;

        private readonly MicrosoftProjectXmlParser _xmlParser;
        private readonly MicrosoftProjectXmlWriter _xmlWriter;
        private readonly ProjectInteropImportService _importService;
        private readonly ProjectInteropExportService _exportService;
        private readonly IProjectAuthorizationService _authorizationService;

        public ProjectInteropController(
            MicrosoftProjectXmlParser xmlParser,
            MicrosoftProjectXmlWriter xmlWriter,
            ProjectInteropImportService importService,
            ProjectInteropExportService exportService,
            IProjectAuthorizationService authorizationService)
        {
            _xmlParser = xmlParser;
            _xmlWriter = xmlWriter;
            _importService = importService;
            _exportService = exportService;
            _authorizationService = authorizationService;
        }

        [HttpPost("import/preview")]
        [Consumes("multipart/form-data")]
        [ProducesResponseType(
            typeof(ProjectImportPreviewDto),
            StatusCodes.Status200OK)]
        [ProducesResponseType(
            StatusCodes.Status400BadRequest)]
        [ProducesResponseType(
            StatusCodes.Status403Forbidden)]
        [ProducesResponseType(
            StatusCodes.Status413PayloadTooLarge)]
        public async Task<ActionResult<ProjectImportPreviewDto>>
            PreviewImportAsync(
                IFormFile file,
                CancellationToken cancellationToken)
        {
            if (!await _authorizationService.CanCreateProjectAsync() ||
                !await _authorizationService.CanManageResourceCatalogAsync())
            {
                return Forbid();
            }

            if (file == null || file.Length == 0)
            {
                return BadRequest(new
                {
                    message =
                        "Aucun fichier XML n'a été fourni."
                });
            }

            var extension =
                Path.GetExtension(file.FileName);

            if (string.IsNullOrWhiteSpace(extension) ||
                !AllowedExtensions.Contains(extension))
            {
                return BadRequest(new
                {
                    message =
                        "Format non supporté. "
                        + "Utilisez un fichier Microsoft Project "
                        + "XML (.xml) ou MSPDI (.mspdi)."
                });
            }

            if (file.Length > MaxPreviewFileSizeBytes)
            {
                return StatusCode(
                    StatusCodes.Status413PayloadTooLarge,
                    new
                    {
                        message =
                            "Le fichier dépasse la taille maximale "
                            + "autorisée de 25 Mo pour le preview."
                    });
            }

            try
            {
                await using var stream =
                    file.OpenReadStream();

                var model =
                    await _xmlParser.ParseAsync(
                        stream,
                        cancellationToken);

                var preview =
                    ProjectImportPreviewDto.FromModel(model);

                return Ok(preview);
            }
            catch (OperationCanceledException)
                when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new
                {
                    message = ex.Message
                });
            }
            catch (Exception)
            {
                return BadRequest(new
                {
                    message =
                        "Le fichier n'a pas pu être analysé "
                        + "comme un projet Microsoft Project XML."
                });
            }
        }

        [HttpPost("import")]
        [Consumes("multipart/form-data")]
        [ProducesResponseType(
            typeof(ProjectInteropImportResult),
            StatusCodes.Status200OK)]
        [ProducesResponseType(
            StatusCodes.Status400BadRequest)]
        [ProducesResponseType(
            StatusCodes.Status403Forbidden)]
        [ProducesResponseType(
            StatusCodes.Status413PayloadTooLarge)]
        public async Task<ActionResult<ProjectInteropImportResult>>
            ImportAsync(
                IFormFile file,
                CancellationToken cancellationToken)
        {
            if (!await _authorizationService.CanCreateProjectAsync() ||
                !await _authorizationService.CanManageResourceCatalogAsync())
            {
                return Forbid();
            }

            if (file == null || file.Length == 0)
            {
                return BadRequest(new
                {
                    message =
                        "Aucun fichier XML n'a été fourni."
                });
            }

            var extension =
                Path.GetExtension(file.FileName);

            if (string.IsNullOrWhiteSpace(extension) ||
                !AllowedExtensions.Contains(extension))
            {
                return BadRequest(new
                {
                    message =
                        "Format non supporté. "
                        + "Utilisez un fichier Microsoft Project "
                        + "XML (.xml) ou MSPDI (.mspdi)."
                });
            }

            if (file.Length > MaxPreviewFileSizeBytes)
            {
                return StatusCode(
                    StatusCodes.Status413PayloadTooLarge,
                    new
                    {
                        message =
                            "Le fichier dépasse la taille maximale "
                            + "autorisée de 25 Mo pour l'import."
                    });
            }

            try
            {
                await using var stream =
                    file.OpenReadStream();

                var model =
                    await _xmlParser.ParseAsync(
                        stream,
                        cancellationToken);

                var result =
                    await _importService.ImportAsync(
                        model,
                        cancellationToken);

                return Ok(result);
            }
            catch (OperationCanceledException)
                when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new
                {
                    message = ex.Message
                });
            }
            catch (DbUpdateException ex)
            {
                return BadRequest(new
                {
                    message =
                        "L'import n'a pas pu être enregistré en base.",
                    detail =
                        ex.InnerException?.Message
                        ?? ex.Message
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new
                {
                    message =
                        "Une erreur est survenue pendant l'import du projet.",
                    detail = ex.Message
                });
            }
        }
        [HttpGet("project/{projectId:int}/export")]
        [Produces("application/xml")]
        [ProducesResponseType(
            typeof(FileContentResult),
            StatusCodes.Status200OK)]
        [ProducesResponseType(
            StatusCodes.Status404NotFound)]
        [ProducesResponseType(
            StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> ExportProjectAsync(
            int projectId,
            CancellationToken cancellationToken)
        {
            if (!await _authorizationService.CanReadProjectAsync(projectId))
            {
                return NotFound(new
                {
                    message =
                        $"Projet avec l'id {projectId} introuvable."
                });
            }

            try
            {
                var model =
                    await _exportService.BuildModelAsync(
                        projectId,
                        cancellationToken);

                var bytes =
                    await _xmlWriter.WriteAsync(
                        model,
                        cancellationToken);

                var exportBaseName =
                    !string.IsNullOrWhiteSpace(
                        model.Project.ProjectCode)
                        ? model.Project.ProjectCode
                        : !string.IsNullOrWhiteSpace(
                            model.Project.Name)
                            ? model.Project.Name
                            : $"Projet_{projectId}";

                var fileName =
                    $"{SanitizeFileName(exportBaseName)}_project.xml";

                return File(
                    bytes,
                    "application/xml",
                    fileName);
            }
            catch (OperationCanceledException)
                when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (InvalidOperationException ex)
            {
                if (ex.Message.Contains(
                        "introuvable",
                        StringComparison.OrdinalIgnoreCase))
                {
                    return NotFound(new
                    {
                        message = ex.Message
                    });
                }

                return BadRequest(new
                {
                    message = ex.Message
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new
                {
                    message =
                        "Une erreur est survenue pendant l'export du projet.",
                    detail = ex.Message
                });
            }
        }

        private static string SanitizeFileName(
            string value)
        {
            var sanitized = value.Trim();

            foreach (var invalidCharacter in
                     Path.GetInvalidFileNameChars())
            {
                sanitized =
                    sanitized.Replace(
                        invalidCharacter,
                        '_');
            }

            sanitized =
                string.Join(
                    "_",
                    sanitized
                        .Split(
                            ' ',
                            StringSplitOptions.RemoveEmptyEntries));

            return string.IsNullOrWhiteSpace(sanitized)
                ? "Projet"
                : sanitized;
        }

    }
}