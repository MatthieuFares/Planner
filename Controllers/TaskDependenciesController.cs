using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Dependencies;
using PlannerAPI.Models;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TaskDependenciesController : ControllerBase
    {
        private readonly AppDbContext _context;

        public TaskDependenciesController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/taskdependencies
        [HttpGet]
        public async Task<ActionResult<IEnumerable<TaskDependencyReadDto>>> GetAll()
        {
            var dependencies = await _context.TaskDependencies
                .Select(td => new TaskDependencyReadDto
                {
                    Id = td.Id,
                    PredecessorId = td.PredecessorId,
                    SuccessorId = td.SuccessorId,
                    Type = td.Type
                })
                .ToListAsync();

            return Ok(dependencies);
        }

        // GET: api/taskdependencies/5
        [HttpGet("{id}")]
        public async Task<ActionResult<TaskDependencyReadDto>> GetById(int id)
        {
            var dependency = await _context.TaskDependencies.FindAsync(id);

            if (dependency == null)
                return NotFound();

            var dto = new TaskDependencyReadDto
            {
                Id = dependency.Id,
                PredecessorId = dependency.PredecessorId,
                SuccessorId = dependency.SuccessorId,
                Type = dependency.Type
            };

            return Ok(dto);
        }

        // GET: api/taskdependencies/task/5
        [HttpGet("task/{taskId}")]
        public async Task<ActionResult<IEnumerable<TaskDependencyReadDto>>> GetByTask(int taskId)
        {
            var dependencies = await _context.TaskDependencies
                .Where(td => td.PredecessorId == taskId || td.SuccessorId == taskId)
                .Select(td => new TaskDependencyReadDto
                {
                    Id = td.Id,
                    PredecessorId = td.PredecessorId,
                    SuccessorId = td.SuccessorId,
                    Type = td.Type
                })
                .ToListAsync();

            return Ok(dependencies);
        }

        // POST: api/taskdependencies
        [HttpPost]
        public async Task<ActionResult<TaskDependencyReadDto>> Create(TaskDependencyCreateDto dto)
        {
            // ❌ Une tâche ne peut pas dépendre d'elle-même
            if (dto.PredecessorId == dto.SuccessorId)
                return BadRequest("Une tâche ne peut pas dépendre d'elle-même.");

            // 🔍 Vérifier existence des tâches
            var predecessorExists = await _context.Tasks.AnyAsync(t => t.Id == dto.PredecessorId);
            var successorExists = await _context.Tasks.AnyAsync(t => t.Id == dto.SuccessorId);

            if (!predecessorExists || !successorExists)
                return NotFound("Une des tâches n'existe pas.");

            // ❌ Empêcher doublon exact
            var alreadyExists = await _context.TaskDependencies.AnyAsync(td =>
                td.PredecessorId == dto.PredecessorId &&
                td.SuccessorId == dto.SuccessorId &&
                td.Type == dto.Type);

            if (alreadyExists)
                return Conflict("Cette dépendance existe déjà.");

            var dependency = new TaskDependency
            {
                PredecessorId = dto.PredecessorId,
                SuccessorId = dto.SuccessorId,
                Type = dto.Type
            };

            _context.TaskDependencies.Add(dependency);
            await _context.SaveChangesAsync();

            var result = new TaskDependencyReadDto
            {
                Id = dependency.Id,
                PredecessorId = dependency.PredecessorId,
                SuccessorId = dependency.SuccessorId,
                Type = dependency.Type
            };

            return CreatedAtAction(nameof(GetById), new { id = dependency.Id }, result);
        }

        // PUT: api/taskdependencies/5
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, TaskDependencyUpdateDto dto)
        {
            var dependency = await _context.TaskDependencies.FindAsync(id);

            if (dependency == null)
                return NotFound();

            if (dto.PredecessorId == dto.SuccessorId)
                return BadRequest("Une tâche ne peut pas dépendre d'elle-même.");

            var predecessorExists = await _context.Tasks.AnyAsync(t => t.Id == dto.PredecessorId);
            var successorExists = await _context.Tasks.AnyAsync(t => t.Id == dto.SuccessorId);

            if (!predecessorExists || !successorExists)
                return NotFound("Une des tâches n'existe pas.");

            dependency.PredecessorId = dto.PredecessorId;
            dependency.SuccessorId = dto.SuccessorId;
            dependency.Type = dto.Type;

            await _context.SaveChangesAsync();

            return NoContent();
        }

        // DELETE: api/taskdependencies/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var dependency = await _context.TaskDependencies.FindAsync(id);

            if (dependency == null)
                return NotFound();

            _context.TaskDependencies.Remove(dependency);
            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}