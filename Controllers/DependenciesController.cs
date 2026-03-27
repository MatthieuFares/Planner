using Microsoft.AspNetCore.Mvc;
using PlannerAPI.Models;
using PlannerAPI.Services;

namespace PlannerAPI.Controllers;

[ApiController]
[Route("[controller]")]
public class DependenciesController : ControllerBase
{
    private readonly DependencyService _service;

    public DependenciesController(DependencyService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _service.GetAllAsync());
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] Dependency dependency)
    {
        if (dependency.PredecessorId == dependency.SuccessorId)
            return BadRequest("A task cannot depend on itself");

        var created = await _service.CreateAsync(dependency);
        return Ok(created);
    }
}