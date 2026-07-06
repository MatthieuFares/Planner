using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.ProjectBaselines;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ProjectBaselineService : IProjectBaselineService
    {
        private readonly AppDbContext _context;

        public ProjectBaselineService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<ProjectBaselineReadDto>?> GetByProjectIdAsync(int projectId)
        {
            var projectExists = await _context.Projects.AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return null;

            var baselines = await _context.ProjectBaselines
                .Include(b => b.Tasks)
                .Where(b => b.ProjectId == projectId)
                .OrderByDescending(b => b.CreatedAt)
                .ToListAsync();

            return baselines.Select(MapToReadDto);
        }

        public async Task<ProjectBaselineDetailDto?> GetByIdAsync(int baselineId)
        {
            var baseline = await _context.ProjectBaselines
                .Include(b => b.Tasks)
                .FirstOrDefaultAsync(b => b.Id == baselineId);

            if (baseline == null)
                return null;

            return MapToDetailDto(baseline);
        }

        public async Task<ProjectBaselineDetailDto?> CreateAsync(
            int projectId,
            ProjectBaselineCreateDto dto)
        {
            var projectExists = await _context.Projects.AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return null;

            var tasks = await _context.Tasks
                .Where(t => t.ProjectId == projectId)
                .OrderBy(t => t.StartDate)
                .ThenBy(t => t.Id)
                .ToListAsync();

            if (dto.SetAsActive)
            {
                var existingBaselines = await _context.ProjectBaselines
                    .Where(b => b.ProjectId == projectId)
                    .ToListAsync();

                foreach (var existingBaseline in existingBaselines)
                {
                    existingBaseline.IsActive = false;
                }
            }

            var baseline = new ProjectBaseline
            {
                ProjectId = projectId,
                Name = dto.Name.Trim(),
                Description = string.IsNullOrWhiteSpace(dto.Description)
                    ? null
                    : dto.Description.Trim(),
                CreatedAt = DateTime.UtcNow,
                IsActive = dto.SetAsActive
            };

            var planningItems = await _context.PlanningItems
                .Where(i => i.ProjectId == projectId && i.TaskId != null)
                .ToListAsync();

            foreach (var task in tasks)
            {
                var planningItem = planningItems.FirstOrDefault(i => i.TaskId == task.Id);

                baseline.Tasks.Add(new ProjectBaselineTask
                {
                    TaskId = task.Id,
                    TaskTitle = task.Title,
                    WbsCode = planningItem?.WbsCode,
                    StartDate = task.StartDate,
                    EndDate = task.EndDate,
                    Duration = task.Duration ?? 0,
                    ProgressPercent = task.ProgressPercent ,
                    Deadline = task.Deadline,
                    TotalFloat = task.TotalFloat ?? 0,
                    IsCritical = task.IsCritical,
                    IsLate = task.IsLate,
                    DelayDays = task.DelayDays 
                });
            }

            _context.ProjectBaselines.Add(baseline);
            await _context.SaveChangesAsync();

            return MapToDetailDto(baseline);
        }

        public async Task<ProjectBaselineComparisonDto?> CompareAsync(int baselineId)
        {
            var baseline = await _context.ProjectBaselines
                .Include(b => b.Tasks)
                .FirstOrDefaultAsync(b => b.Id == baselineId);

            if (baseline == null)
                return null;

            var currentTasks = await _context.Tasks
                .Where(t => t.ProjectId == baseline.ProjectId)
                .ToListAsync();

            var planningItems = await _context.PlanningItems
                .Where(i => i.ProjectId == baseline.ProjectId && i.TaskId != null)
                .ToListAsync();

            var comparison = new ProjectBaselineComparisonDto
            {
                BaselineId = baseline.Id,
                ProjectId = baseline.ProjectId,
                BaselineName = baseline.Name,
                CreatedAt = baseline.CreatedAt,
                IsActive = baseline.IsActive
            };

            foreach (var baselineTask in baseline.Tasks.OrderBy(t => t.WbsCode).ThenBy(t => t.TaskId))
            {
                var currentTask = currentTasks.FirstOrDefault(t => t.Id == baselineTask.TaskId);
                var planningItem = planningItems.FirstOrDefault(i => i.TaskId == baselineTask.TaskId);

                if (currentTask == null)
                {
                    comparison.Rows.Add(new ProjectBaselineComparisonRowDto
                    {
                        TaskId = baselineTask.TaskId,
                        TaskTitle = baselineTask.TaskTitle,
                        WbsCode = baselineTask.WbsCode,
                        BaselineStartDate = baselineTask.StartDate,
                        CurrentStartDate = null,
                        StartVarianceDays = null,
                        BaselineEndDate = baselineTask.EndDate,
                        CurrentEndDate = null,
                        EndVarianceDays = null,
                        BaselineDuration = baselineTask.Duration,
                        CurrentDuration = 0,
                        DurationVarianceDays = -baselineTask.Duration,
                        BaselineProgressPercent = baselineTask.ProgressPercent,
                        CurrentProgressPercent = 0,
                        ProgressVariancePercent = -baselineTask.ProgressPercent,
                        BaselineDeadline = baselineTask.Deadline,
                        CurrentDeadline = null,
                        BaselineTotalFloat = baselineTask.TotalFloat,
                        CurrentTotalFloat = 0,
                        TotalFloatVariance = -baselineTask.TotalFloat,
                        BaselineIsCritical = baselineTask.IsCritical,
                        CurrentIsCritical = false,
                        BaselineIsLate = baselineTask.IsLate,
                        CurrentIsLate = false,
                        BaselineDelayDays = baselineTask.DelayDays,
                        CurrentDelayDays = 0,
                        IsDelayedComparedToBaseline = false,
                        IsMissingFromCurrentPlanning = true
                    });

                    continue;
                }

                var startVariance = CalculateDateVariance(
                    baselineTask.StartDate,
                    currentTask.StartDate);

                var endVariance = CalculateDateVariance(
                    baselineTask.EndDate,
                    currentTask.EndDate);

                comparison.Rows.Add(new ProjectBaselineComparisonRowDto
                {
                    TaskId = baselineTask.TaskId,
                    TaskTitle = currentTask.Title,
                    WbsCode = planningItem?.WbsCode ?? baselineTask.WbsCode,

                    BaselineStartDate = baselineTask.StartDate,
                    CurrentStartDate = currentTask.StartDate,
                    StartVarianceDays = startVariance,

                    BaselineEndDate = baselineTask.EndDate,
                    CurrentEndDate = currentTask.EndDate,
                    EndVarianceDays = endVariance,

                    BaselineDuration = baselineTask.Duration,
                    CurrentDuration = currentTask.Duration ?? 0,
                    DurationVarianceDays = (currentTask.Duration ?? 0) - baselineTask.Duration,

                    BaselineProgressPercent = baselineTask.ProgressPercent,
                    CurrentProgressPercent = currentTask.ProgressPercent,
                    ProgressVariancePercent = currentTask.ProgressPercent - baselineTask.ProgressPercent,

                    BaselineDeadline = baselineTask.Deadline,
                    CurrentDeadline = currentTask.Deadline,

                    BaselineTotalFloat = baselineTask.TotalFloat,
                    CurrentTotalFloat = currentTask.TotalFloat ?? 0,
                    TotalFloatVariance = (currentTask.TotalFloat ?? 0) - baselineTask.TotalFloat,

                    BaselineIsCritical = baselineTask.IsCritical,
                    CurrentIsCritical = currentTask.IsCritical,

                    BaselineIsLate = baselineTask.IsLate,
                    CurrentIsLate = currentTask.IsLate,

                    BaselineDelayDays = baselineTask.DelayDays,
                    CurrentDelayDays = currentTask.DelayDays,

                    IsDelayedComparedToBaseline = endVariance.HasValue && endVariance.Value > 0,
                    IsMissingFromCurrentPlanning = false
                });
            }

            return comparison;
        }

        public async Task<ProjectBaselineReadDto?> SetActiveAsync(int baselineId)
        {
            var baseline = await _context.ProjectBaselines
                .Include(b => b.Tasks)
                .FirstOrDefaultAsync(b => b.Id == baselineId);

            if (baseline == null)
                return null;

            var projectBaselines = await _context.ProjectBaselines
                .Where(b => b.ProjectId == baseline.ProjectId)
                .ToListAsync();

            foreach (var projectBaseline in projectBaselines)
            {
                projectBaseline.IsActive = projectBaseline.Id == baselineId;
            }

            await _context.SaveChangesAsync();

            return MapToReadDto(baseline);
        }

        public async Task<bool> DeleteAsync(int baselineId)
        {
            var baseline = await _context.ProjectBaselines
                .FirstOrDefaultAsync(b => b.Id == baselineId);

            if (baseline == null)
                return false;

            _context.ProjectBaselines.Remove(baseline);
            await _context.SaveChangesAsync();

            return true;
        }

        private static int? CalculateDateVariance(DateTime? baselineDate, DateTime? currentDate)
        {
            if (baselineDate == null || currentDate == null)
                return null;

            return currentDate.Value.Date
                .Subtract(baselineDate.Value.Date)
                .Days;
        }

        private static ProjectBaselineReadDto MapToReadDto(ProjectBaseline baseline)
        {
            return new ProjectBaselineReadDto
            {
                Id = baseline.Id,
                ProjectId = baseline.ProjectId,
                Name = baseline.Name,
                Description = baseline.Description,
                CreatedAt = baseline.CreatedAt,
                IsActive = baseline.IsActive,
                TaskCount = baseline.Tasks.Count
            };
        }

        private static ProjectBaselineDetailDto MapToDetailDto(ProjectBaseline baseline)
        {
            return new ProjectBaselineDetailDto
            {
                Id = baseline.Id,
                ProjectId = baseline.ProjectId,
                Name = baseline.Name,
                Description = baseline.Description,
                CreatedAt = baseline.CreatedAt,
                IsActive = baseline.IsActive,
                Tasks = baseline.Tasks
                    .OrderBy(t => t.WbsCode)
                    .ThenBy(t => t.TaskId)
                    .Select(MapToTaskReadDto)
                    .ToList()
            };
        }

        private static ProjectBaselineTaskReadDto MapToTaskReadDto(
            ProjectBaselineTask task)
        {
            return new ProjectBaselineTaskReadDto
            {
                Id = task.Id,
                ProjectBaselineId = task.ProjectBaselineId,
                TaskId = task.TaskId,
                TaskTitle = task.TaskTitle,
                WbsCode = task.WbsCode,
                StartDate = task.StartDate,
                EndDate = task.EndDate,
                Duration = task.Duration,
                ProgressPercent = task.ProgressPercent,
                Deadline = task.Deadline,
                TotalFloat = task.TotalFloat,
                IsCritical = task.IsCritical,
                IsLate = task.IsLate,
                DelayDays = task.DelayDays
            };
        }
    }
}