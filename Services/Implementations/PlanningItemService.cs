using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.PlanningItems;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class PlanningItemService : IPlanningItemService
    {
        private readonly AppDbContext _context;

        public PlanningItemService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<PlanningItemReadDto>> GetByProjectIdAsync(int projectId)
        {
            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                throw new InvalidOperationException($"Projet avec l'id {projectId} introuvable.");

            var items = await _context.PlanningItems
                .AsNoTracking()
                .Include(i => i.Task)
                .Where(i => i.ProjectId == projectId)
                .OrderBy(i => i.WbsCode)
                .ThenBy(i => i.SortOrder)
                .ThenBy(i => i.Id)
                .ToListAsync();

            return items.Select(item => MapToReadDto(item, items));
        }

        public async Task<PlanningItemReadDto?> GetByIdAsync(int id)
        {
            var item = await _context.PlanningItems
                .AsNoTracking()
                .Include(i => i.Task)
                .FirstOrDefaultAsync(i => i.Id == id);

            if (item == null)
                return null;

            var projectItems = await _context.PlanningItems
                .AsNoTracking()
                .Where(i => i.ProjectId == item.ProjectId)
                .ToListAsync();

            return MapToReadDto(item, projectItems);
        }

        public async Task<PlanningItemReadDto> CreateAsync(PlanningItemCreateDto dto)
        {
            var type = ParsePlanningItemType(dto.Type);

            await ValidateReferencesAsync(
                projectId: dto.ProjectId,
                parentId: dto.ParentId,
                taskId: dto.TaskId,
                type: type,
                currentItemId: null
            );

            var sortOrder = dto.SortOrder > 0
                ? dto.SortOrder
                : await GetNextSortOrderAsync(dto.ProjectId, dto.ParentId);

            var item = new PlanningItem
            {
                ProjectId = dto.ProjectId,
                ParentId = dto.ParentId,
                Name = NormalizeRequiredText(dto.Name, "Le nom de l'élément de planning est obligatoire."),
                Type = type,
                SortOrder = sortOrder,
                TaskId = dto.TaskId
            };

            _context.PlanningItems.Add(item);

            await _context.SaveChangesAsync();

            await RecalculateProjectWbsCodesAsync(dto.ProjectId);

            var createdItem = await _context.PlanningItems
                .AsNoTracking()
                .Include(i => i.Task)
                .FirstAsync(i => i.Id == item.Id);

            var projectItems = await _context.PlanningItems
                .AsNoTracking()
                .Where(i => i.ProjectId == dto.ProjectId)
                .ToListAsync();

            return MapToReadDto(createdItem, projectItems);
        }

        public async Task<PlanningItemReadDto?> UpdateAsync(int id, PlanningItemUpdateDto dto)
        {
            var item = await _context.PlanningItems
                .FirstOrDefaultAsync(i => i.Id == id);

            if (item == null)
                return null;

            var type = ParsePlanningItemType(dto.Type);

            await ValidateReferencesAsync(
                projectId: item.ProjectId,
                parentId: dto.ParentId,
                taskId: dto.TaskId,
                type: type,
                currentItemId: id
            );

            if (dto.ParentId == id)
            {
                throw new InvalidOperationException(
                    "Un élément de planning ne peut pas être son propre parent."
                );
            }

            if (dto.ParentId.HasValue)
            {
                var createsCycle = await CreatesHierarchyCycleAsync(
                    itemId: id,
                    newParentId: dto.ParentId.Value
                );

                if (createsCycle)
                {
                    throw new InvalidOperationException(
                        "Ce déplacement créerait un cycle dans la hiérarchie du planning."
                    );
                }
            }

            item.ParentId = dto.ParentId;
            item.Name = NormalizeRequiredText(dto.Name, "Le nom de l'élément de planning est obligatoire.");
            item.Type = type;
            item.SortOrder = dto.SortOrder > 0
                ? dto.SortOrder
                : item.SortOrder;
            item.TaskId = dto.TaskId;

            await _context.SaveChangesAsync();

            await RecalculateProjectWbsCodesAsync(item.ProjectId);

            var updatedItem = await _context.PlanningItems
                .AsNoTracking()
                .Include(i => i.Task)
                .FirstOrDefaultAsync(i => i.Id == id);

            if (updatedItem == null)
                return null;

            var projectItems = await _context.PlanningItems
                .AsNoTracking()
                .Where(i => i.ProjectId == updatedItem.ProjectId)
                .ToListAsync();

            return MapToReadDto(updatedItem, projectItems);
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var item = await _context.PlanningItems
                .Include(i => i.Children)
                .FirstOrDefaultAsync(i => i.Id == id);

            if (item == null)
                return false;

            if (item.Children.Any())
            {
                throw new InvalidOperationException(
                    "Impossible de supprimer cet élément car il contient des sous-éléments."
                );
            }

            var projectId = item.ProjectId;

            _context.PlanningItems.Remove(item);

            await _context.SaveChangesAsync();

            await RecalculateProjectWbsCodesAsync(projectId);

            return true;
        }

        public async Task<PlanningItemSyncResultDto> SyncProjectTasksAsync(int projectId)
        {
            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                throw new InvalidOperationException($"Projet avec l'id {projectId} introuvable.");

            var projectTaskIds = await _context.Tasks
                .Where(t => t.ProjectId == projectId)
                .Select(t => t.Id)
                .ToListAsync();

            var orphanTaskItems = await _context.PlanningItems
                .Where(i =>
                    i.ProjectId == projectId &&
                    i.Type == PlanningItemType.Task &&
                    (
                        !i.TaskId.HasValue ||
                        !projectTaskIds.Contains(i.TaskId.Value)
                    ))
                .ToListAsync();

            var deletedOrphanItems = orphanTaskItems.Count;

            if (orphanTaskItems.Any())
            {
                _context.PlanningItems.RemoveRange(orphanTaskItems);
                await _context.SaveChangesAsync();
            }

            var existingTaskIds = await _context.PlanningItems
                .Where(i =>
                    i.ProjectId == projectId &&
                    i.Type == PlanningItemType.Task &&
                    i.TaskId.HasValue)
                .Select(i => i.TaskId!.Value)
                .ToListAsync();

            var tasksToSync = await _context.Tasks
                .Where(t => t.ProjectId == projectId && !existingTaskIds.Contains(t.Id))
                .OrderBy(t => t.StartDate)
                .ThenBy(t => t.Id)
                .ToListAsync();

            if (!tasksToSync.Any())
            {
                await RecalculateProjectWbsCodesAsync(projectId);

                return new PlanningItemSyncResultDto
                {
                    Message = deletedOrphanItems > 0
                        ? $"Synchronisation terminée. {deletedOrphanItems} élément(s) orphelin(s) supprimé(s)."
                        : "Aucune tâche à synchroniser.",
                    CreatedItems = 0
                };
            }

            var unclassifiedSection = await _context.PlanningItems
                .FirstOrDefaultAsync(i =>
                    i.ProjectId == projectId &&
                    i.ParentId == null &&
                    i.Name == "Tâches non classées");

            if (unclassifiedSection == null)
            {
                var nextRootSortOrder = await _context.PlanningItems
                    .Where(i => i.ProjectId == projectId && i.ParentId == null)
                    .Select(i => (int?)i.SortOrder)
                    .MaxAsync() ?? 0;

                nextRootSortOrder++;

                unclassifiedSection = new PlanningItem
                {
                    ProjectId = projectId,
                    ParentId = null,
                    Name = "Tâches non classées",
                    Type = PlanningItemType.Section,
                    SortOrder = nextRootSortOrder,
                    WbsCode = nextRootSortOrder.ToString(),
                    TaskId = null
                };

                _context.PlanningItems.Add(unclassifiedSection);
                await _context.SaveChangesAsync();
            }

            var nextChildSortOrder = await _context.PlanningItems
                .Where(i => i.ProjectId == projectId && i.ParentId == unclassifiedSection.Id)
                .Select(i => (int?)i.SortOrder)
                .MaxAsync() ?? 0;

            foreach (var task in tasksToSync)
            {
                nextChildSortOrder++;

                var item = new PlanningItem
                {
                    ProjectId = projectId,
                    ParentId = unclassifiedSection.Id,
                    Name = task.Title,
                    Type = PlanningItemType.Task,
                    SortOrder = nextChildSortOrder,
                    WbsCode = $"{unclassifiedSection.WbsCode}.{nextChildSortOrder}",
                    TaskId = task.Id
                };

                _context.PlanningItems.Add(item);
            }

            await _context.SaveChangesAsync();

            await RecalculateProjectWbsCodesAsync(projectId);

            return new PlanningItemSyncResultDto
            {
                Message = deletedOrphanItems > 0
                    ? $"Synchronisation terminée. {tasksToSync.Count} tâche(s) créée(s), {deletedOrphanItems} élément(s) orphelin(s) supprimé(s)."
                    : $"Synchronisation terminée. {tasksToSync.Count} tâche(s) créée(s).",
                CreatedItems = tasksToSync.Count
            };
        }

        public async Task<PlanningItemReadDto?> MoveAsync(int id, PlanningItemMoveDto dto)
        {
            var item = await _context.PlanningItems
                .FirstOrDefaultAsync(i => i.Id == id);

            if (item == null)
                return null;

            if (item.Type != PlanningItemType.Task)
                throw new InvalidOperationException("Seules les tâches peuvent être déplacées pour le moment.");

            var newParent = await _context.PlanningItems
                .FirstOrDefaultAsync(i => i.Id == dto.NewParentId);

            if (newParent == null)
                throw new InvalidOperationException($"Parent cible avec l'id {dto.NewParentId} introuvable.");

            if (newParent.ProjectId != item.ProjectId)
                throw new InvalidOperationException("Impossible de déplacer un élément vers un autre projet.");

            if (newParent.Type != PlanningItemType.Section &&
                newParent.Type != PlanningItemType.Zone)
                throw new InvalidOperationException("Le parent cible doit être une Section ou une Zone.");

            var nextSortOrder = await _context.PlanningItems
                .Where(i => i.ProjectId == item.ProjectId && i.ParentId == newParent.Id)
                .Select(i => (int?)i.SortOrder)
                .MaxAsync() ?? 0;

            nextSortOrder++;

            item.ParentId = newParent.Id;
            item.SortOrder = nextSortOrder;

            await _context.SaveChangesAsync();

            await RecalculateProjectWbsCodesAsync(item.ProjectId);

            var updatedItem = await _context.PlanningItems
                .AsNoTracking()
                .Include(i => i.Task)
                .FirstOrDefaultAsync(i => i.Id == id);

            if (updatedItem == null)
                return null;

            var projectItems = await _context.PlanningItems
                .AsNoTracking()
                .Where(i => i.ProjectId == updatedItem.ProjectId)
                .ToListAsync();

            return MapToReadDto(updatedItem, projectItems);
        }

        private async Task ValidateReferencesAsync(
            int projectId,
            int? parentId,
            int? taskId,
            PlanningItemType type,
            int? currentItemId)
        {
            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                throw new InvalidOperationException($"Projet avec l'id {projectId} introuvable.");

            if (parentId.HasValue)
            {
                var parent = await _context.PlanningItems
                    .AsNoTracking()
                    .FirstOrDefaultAsync(i => i.Id == parentId.Value);

                if (parent == null)
                    throw new InvalidOperationException($"Parent avec l'id {parentId.Value} introuvable.");

                if (parent.ProjectId != projectId)
                {
                    throw new InvalidOperationException(
                        "Le parent doit appartenir au même projet."
                    );
                }
            }

            if (type == PlanningItemType.Task && !taskId.HasValue)
            {
                throw new InvalidOperationException(
                    "Un élément de type Task doit être lié à une tâche."
                );
            }

            if (type != PlanningItemType.Task && taskId.HasValue)
            {
                throw new InvalidOperationException(
                    "Seul un élément de type Task peut être lié à une tâche."
                );
            }

            if (taskId.HasValue)
            {
                var task = await _context.Tasks
                    .AsNoTracking()
                    .FirstOrDefaultAsync(t => t.Id == taskId.Value);

                if (task == null)
                    throw new InvalidOperationException($"Tâche avec l'id {taskId.Value} introuvable.");

                if (task.ProjectId != projectId)
                {
                    throw new InvalidOperationException(
                        "La tâche liée doit appartenir au même projet."
                    );
                }

                var taskAlreadyLinked = await _context.PlanningItems.AnyAsync(i =>
                    i.TaskId == taskId.Value &&
                    (!currentItemId.HasValue || i.Id != currentItemId.Value)
                );

                if (taskAlreadyLinked)
                {
                    throw new InvalidOperationException(
                        "Cette tâche est déjà liée à un élément de planning."
                    );
                }
            }
        }

        private async Task<int> GetNextSortOrderAsync(int projectId, int? parentId)
        {
            var currentMax = await _context.PlanningItems
                .Where(i => i.ProjectId == projectId && i.ParentId == parentId)
                .MaxAsync(i => (int?)i.SortOrder);

            return (currentMax ?? 0) + 1;
        }

        private async Task RecalculateProjectWbsCodesAsync(int projectId)
        {
            var items = await _context.PlanningItems
                .Where(i => i.ProjectId == projectId)
                .ToListAsync();

            ApplyWbsCodes(items, parentId: null, prefix: string.Empty);

            await _context.SaveChangesAsync();
        }

        private static void ApplyWbsCodes(
            List<PlanningItem> items,
            int? parentId,
            string prefix)
        {
            var children = items
                .Where(i => i.ParentId == parentId)
                .OrderBy(i => i.SortOrder)
                .ThenBy(i => i.Id)
                .ToList();

            for (var index = 0; index < children.Count; index++)
            {
                var child = children[index];

                child.WbsCode = string.IsNullOrWhiteSpace(prefix)
                    ? $"{index + 1}"
                    : $"{prefix}.{index + 1}";

                ApplyWbsCodes(items, child.Id, child.WbsCode);
            }
        }

        private async Task<bool> CreatesHierarchyCycleAsync(int itemId, int newParentId)
        {
            var currentParentId = newParentId;
            var visited = new HashSet<int>();

            while (true)
            {
                if (!visited.Add(currentParentId))
                    return true;

                if (currentParentId == itemId)
                    return true;

                var parent = await _context.PlanningItems
                    .AsNoTracking()
                    .FirstOrDefaultAsync(i => i.Id == currentParentId);

                if (parent == null || !parent.ParentId.HasValue)
                    return false;

                currentParentId = parent.ParentId.Value;
            }
        }

        private static PlanningItemType ParsePlanningItemType(string type)
        {
            if (string.IsNullOrWhiteSpace(type))
            {
                throw new InvalidOperationException(
                    "Le type d'élément est obligatoire. Valeurs autorisées : Section, Phase, Zone, Floor, Lot, Task."
                );
            }

            var parsed = Enum.TryParse<PlanningItemType>(
                type,
                ignoreCase: true,
                out var planningItemType
            );

            if (!parsed || !Enum.IsDefined(typeof(PlanningItemType), planningItemType))
            {
                throw new InvalidOperationException(
                    "Type d'élément invalide. Valeurs autorisées : Section, Phase, Zone, Floor, Lot, Task."
                );
            }

            return planningItemType;
        }

        private static string NormalizeRequiredText(string? value, string errorMessage)
        {
            if (string.IsNullOrWhiteSpace(value))
                throw new InvalidOperationException(errorMessage);

            return value.Trim();
        }

        private static PlanningItemReadDto MapToReadDto(
            PlanningItem item,
            List<PlanningItem> projectItems)
        {
            var level = GetLevel(item, projectItems);

            return new PlanningItemReadDto
            {
                Id = item.Id,
                ProjectId = item.ProjectId,
                ParentId = item.ParentId,

                Name = item.Name,
                Type = item.Type.ToString(),
                SortOrder = item.SortOrder,
                WbsCode = item.WbsCode,
                Level = level,

                TaskId = item.TaskId,
                TaskTitle = item.Task?.Title,
                TaskStartDate = item.Task?.StartDate,
                TaskEndDate = item.Task?.EndDate,
                TaskDuration = item.Task?.Duration,
                TaskProgressPercent = item.Task?.ProgressPercent,
                TaskIsDone = item.Task?.IsDone,
                TaskIsCritical = item.Task?.IsCritical,
                TaskTotalFloat = item.Task?.TotalFloat
            };
        }

        private static int GetLevel(
            PlanningItem item,
            List<PlanningItem> projectItems)
        {
            var level = 0;
            var currentParentId = item.ParentId;
            var visited = new HashSet<int>();

            while (currentParentId.HasValue)
            {
                if (!visited.Add(currentParentId.Value))
                    break;

                var parent = projectItems
                    .FirstOrDefault(i => i.Id == currentParentId.Value);

                if (parent == null)
                    break;

                level++;
                currentParentId = parent.ParentId;
            }

            return level;
        }
    }
}