using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.AccessManagement;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/access-management")]
    public class AccessManagementController :
        ControllerBase
    {
        private readonly IAccessManagementService
            _service;

        public AccessManagementController(
            IAccessManagementService service)
        {
            _service = service;
        }

        [HttpGet]
        public async Task<
            ActionResult<AccessManagementOverviewDto>>
            GetOverview()
        {
            try
            {
                return Ok(
                    await _service.GetOverviewAsync());
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
        }

        [HttpPut(
            "users/{userId}/permissions")]
        public async Task<IActionResult>
            UpdateGlobalPermissions(
                string userId,
                GlobalUserPermissionsUpdateDto dto)
        {
            try
            {
                await _service
                    .UpdateGlobalPermissionsAsync(
                        userId,
                        dto);

                return NoContent();
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(
                    new { message = ex.Message });
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(
                    new { message = ex.Message });
            }
        }
    }
}
