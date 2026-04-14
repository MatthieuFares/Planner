using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class TaskSchedulingService : ITaskSchedulingService
    {
        private readonly AppDbContext _context;

        public TaskSchedulingService(AppDbContext context)
        {
            _context = context;
        }

        public async Task RecalculateTaskDatesAsync(int taskId)
        {
            var visited = new HashSet<int>();
            await RecalculateTaskDatesInternalAsync(taskId, visited);
        }

        private async Task RecalculateTaskDatesInternalAsync(int taskId, HashSet<int> visited)
        {
            // Sécurité supplémentaire : évite de recalculer 2 fois la même tâche
            // dans une même cascade, et protège localement d'une boucle accidentelle.
            if (!visited.Add(taskId))
                return;

            var task = await _context.Tasks
                .Include(t => t.Predecessors)
                    .ThenInclude(d => d.Predecessor)
                .Include(t => t.Successors)
                    .ThenInclude(d => d.Successor)
                .FirstOrDefaultAsync(t => t.Id == taskId);

            if (task == null)
                return;

            DateTime? latestStartConstraint = null;
            DateTime? latestEndConstraint = null;

            foreach (var dependency in task.Predecessors)
            {
                var predecessor = dependency.Predecessor;
                if (predecessor == null)
                    continue;

                switch (dependency.Type)
                {
                    case DependencyType.FS:
                        // Le successeur commence quand le prédécesseur finit
                        if (predecessor.EndDate.HasValue)
                        {
                            latestStartConstraint = MaxDate(latestStartConstraint, predecessor.EndDate.Value);
                        }
                        break;

                    case DependencyType.SS:
                        // Le successeur commence quand le prédécesseur commence
                        if (predecessor.StartDate.HasValue)
                        {
                            latestStartConstraint = MaxDate(latestStartConstraint, predecessor.StartDate.Value);
                        }
                        break;

                    case DependencyType.FF:
                        // Le successeur finit quand le prédécesseur finit
                        if (predecessor.EndDate.HasValue)
                        {
                            latestEndConstraint = MaxDate(latestEndConstraint, predecessor.EndDate.Value);
                        }
                        break;

                    case DependencyType.SF:
                        // Le successeur finit quand le prédécesseur commence
                        if (predecessor.StartDate.HasValue)
                        {
                            latestEndConstraint = MaxDate(latestEndConstraint, predecessor.StartDate.Value);
                        }
                        break;
                }
            }

            ApplySchedulingRules(task, latestStartConstraint, latestEndConstraint);

            await _context.SaveChangesAsync();

            var successorIds = task.Successors
                .Select(s => s.SuccessorId)
                .Distinct()
                .ToList();

            foreach (var successorId in successorIds)
            {
                await RecalculateTaskDatesInternalAsync(successorId, visited);
            }
        }

        private static void ApplySchedulingRules(
            PlannerTask task,
            DateTime? latestStartConstraint,
            DateTime? latestEndConstraint)
        {
            // Sans durée, on ne peut pas recalculer proprement l'autre borne.
            if (!task.Duration.HasValue)
                return;

            var duration = task.Duration.Value;

            // Cas 1 : on a à la fois une contrainte de début et une contrainte de fin
            if (latestStartConstraint.HasValue && latestEndConstraint.HasValue)
            {
                var expectedEnd = latestStartConstraint.Value.AddDays(duration);

                if (expectedEnd > latestEndConstraint.Value)
                {
                    throw new InvalidOperationException(
                        $"Conflit de planification pour la tâche {task.Id} : " +
                        "les contraintes de début et de fin sont incompatibles avec la durée."
                    );
                }

                // On fixe le début à la contrainte la plus tardive côté start
                // puis on déduit la fin à partir de la durée.
                task.StartDate = latestStartConstraint.Value;
                task.EndDate = task.StartDate.Value.AddDays(duration);
                return;
            }

            // Cas 2 : contrainte de début uniquement
            if (latestStartConstraint.HasValue)
            {
                task.StartDate = latestStartConstraint.Value;
                task.EndDate = task.StartDate.Value.AddDays(duration);
                return;
            }

            // Cas 3 : contrainte de fin uniquement
            if (latestEndConstraint.HasValue)
            {
                task.EndDate = latestEndConstraint.Value;
                task.StartDate = task.EndDate.Value.AddDays(-duration);
                return;
            }

            // Cas 4 : aucune contrainte externe
            // On complète les dates si possible à partir d'une borne déjà connue.
            if (task.StartDate.HasValue)
            {
                task.EndDate = task.StartDate.Value.AddDays(duration);
            }
            else if (task.EndDate.HasValue)
            {
                task.StartDate = task.EndDate.Value.AddDays(-duration);
            }
        }

        private static DateTime MaxDate(DateTime? current, DateTime candidate)
        {
            return !current.HasValue || candidate > current.Value
                ? candidate
                : current.Value;
        }
    }
}