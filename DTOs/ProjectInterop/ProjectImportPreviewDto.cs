namespace PlannerAPI.DTOs.ProjectInterop
{
    public class ProjectImportPreviewDto
    {
        public string ProjectName { get; set; } = string.Empty;

        public string? Description { get; set; }

        public string? ClientName { get; set; }

        public string? ProjectCode { get; set; }

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        public int StructureItemCount { get; set; }

        public int TaskCount { get; set; }

        public int DependencyCount { get; set; }

        public int ResourceCount { get; set; }

        public int AssignmentCount { get; set; }

        public bool HasCalendar { get; set; }

        public int CalendarExceptionCount { get; set; }

        public int CalendarPeriodCount { get; set; }

        public bool CanImport { get; set; }

        public int WarningCount { get; set; }

        public int ErrorCount { get; set; }

        public List<ProjectInteropWarning> Warnings { get; set; } = new();

        public static ProjectImportPreviewDto FromModel(
            ProjectInteropModel model)
        {
            var structureItemCount = model.Tasks.Count(
                task => task.IsSummary);

            var taskCount = model.Tasks.Count(
                task => !task.IsSummary);

            var warnings = model.Warnings
                .OrderByDescending(warning =>
                    string.Equals(
                        warning.Severity,
                        "Error",
                        StringComparison.OrdinalIgnoreCase))
                .ThenBy(warning => warning.EntityType)
                .ThenBy(warning => warning.EntityName)
                .ThenBy(warning => warning.Code)
                .ToList();

            var errorCount = warnings.Count(
                warning => string.Equals(
                    warning.Severity,
                    "Error",
                    StringComparison.OrdinalIgnoreCase));

            return new ProjectImportPreviewDto
            {
                ProjectName = model.Project.Name,
                Description = model.Project.Description,
                ClientName = model.Project.ClientName,
                ProjectCode = model.Project.ProjectCode,
                StartDate = model.Project.StartDate,
                EndDate = model.Project.EndDate,

                StructureItemCount = structureItemCount,
                TaskCount = taskCount,
                DependencyCount = model.Dependencies.Count,
                ResourceCount = model.Resources.Count,
                AssignmentCount = model.Assignments.Count,

                HasCalendar = model.Calendar != null,
                CalendarExceptionCount =
                    model.Calendar?.Exceptions.Count ?? 0,
                CalendarPeriodCount =
                    model.Calendar?.Periods.Count ?? 0,

                CanImport = errorCount == 0,
                WarningCount = warnings.Count - errorCount,
                ErrorCount = errorCount,
                Warnings = warnings
            };
        }
    }
}