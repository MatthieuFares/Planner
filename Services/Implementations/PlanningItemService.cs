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
                .ToListAsync();

            var orderedItems = OrderItemsByHierarchy(items);

            return orderedItems.Select(item => MapToReadDto(item, items));
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

            var projectTasks = await _context.Tasks
                .Where(t => t.ProjectId == projectId)
                .OrderBy(t => t.StartDate)
                .ThenBy(t => t.Id)
                .ToListAsync();

            var projectTaskIds = projectTasks
                .Select(t => t.Id)
                .ToList();

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

            var linkedTaskItems = await _context.PlanningItems
                .Where(i =>
                    i.ProjectId == projectId &&
                    i.Type == PlanningItemType.Task &&
                    i.TaskId.HasValue)
                .ToListAsync();

            var projectTasksById = projectTasks
                .ToDictionary(t => t.Id);

            var renamedItems = 0;

            foreach (var planningItem in linkedTaskItems)
            {
                if (!planningItem.TaskId.HasValue)
                    continue;

                if (!projectTasksById.TryGetValue(
                        planningItem.TaskId.Value,
                        out var linkedTask))
                    continue;

                if (planningItem.Name == linkedTask.Title)
                    continue;

                planningItem.Name = linkedTask.Title;
                renamedItems++;
            }

            if (renamedItems > 0)
            {
                await _context.SaveChangesAsync();
            }

            var existingTaskIds = linkedTaskItems
                .Where(i => i.TaskId.HasValue)
                .Select(i => i.TaskId!.Value)
                .ToHashSet();

            var tasksToSync = projectTasks
                .Where(t => !existingTaskIds.Contains(t.Id))
                .ToList();

            if (!tasksToSync.Any())
            {
                await RecalculateProjectWbsCodesAsync(projectId);

                var changes = new List<string>();

                if (renamedItems > 0)
                    changes.Add($"{renamedItems} nom(s) de tâche mis à jour");

                if (deletedOrphanItems > 0)
                    changes.Add($"{deletedOrphanItems} élément(s) orphelin(s) supprimé(s)");

                return new PlanningItemSyncResultDto
                {
                    Message = changes.Any()
                        ? $"Synchronisation terminée. {string.Join(", ", changes)}."
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

            var resultParts = new List<string>
            {
                $"{tasksToSync.Count} tâche(s) créée(s)"
            };

            if (renamedItems > 0)
                resultParts.Add($"{renamedItems} nom(s) de tâche mis à jour");

            if (deletedOrphanItems > 0)
                resultParts.Add($"{deletedOrphanItems} élément(s) orphelin(s) supprimé(s)");

            return new PlanningItemSyncResultDto
            {
                Message = $"Synchronisation terminée. {string.Join(", ", resultParts)}.",
                CreatedItems = tasksToSync.Count
            };
        }

        public async Task<PlanningItemReadDto?> MoveAsync(int id, PlanningItemMoveDto dto)
        {
            var item = await _context.PlanningItems
                .FirstOrDefaultAsync(i => i.Id == id);

            if (item == null)
                return null;

            if (dto.NewParentId == id)
            {
                throw new InvalidOperationException(
                    "Un élément de planning ne peut pas être son propre parent."
                );
            }

            if (!dto.NewParentId.HasValue)
            {
                if (item.Type == PlanningItemType.Task)
                {
                    throw new InvalidOperationException(
                        "Une tâche doit rester rattachée à un élément structurel."
                    );
                }
            }
            else
            {
                var newParent = await _context.PlanningItems
                    .AsNoTracking()
                    .FirstOrDefaultAsync(i => i.Id == dto.NewParentId.Value);

                if (newParent == null)
                {
                    throw new InvalidOperationException(
                        $"Parent cible avec l'id {dto.NewParentId.Value} introuvable."
                    );
                }

                if (newParent.ProjectId != item.ProjectId)
                {
                    throw new InvalidOperationException(
                        "Impossible de déplacer un élément vers un autre projet."
                    );
                }

                if (newParent.Type == PlanningItemType.Task)
                {
                    throw new InvalidOperationException(
                        "Une tâche ne peut pas contenir de sous-éléments."
                    );
                }

                var createsCycle = await CreatesHierarchyCycleAsync(
                    itemId: id,
                    newParentId: newParent.Id
                );

                if (createsCycle)
                {
                    throw new InvalidOperationException(
                        "Ce déplacement créerait un cycle dans la hiérarchie du planning."
                    );
                }
            }

            var nextSortOrder = await GetNextSortOrderAsync(
                item.ProjectId,
                dto.NewParentId
            );

            item.ParentId = dto.NewParentId;
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

                if (parent.Type == PlanningItemType.Task)
                {
                    throw new InvalidOperationException(
                        "Une tâche ne peut pas contenir de sous-éléments."
                    );
                }
            }

            if (type == PlanningItemType.Task && !parentId.HasValue)
            {
                throw new InvalidOperationException(
                    "Une tâche doit être rattachée à un élément structurel."
                );
            }

            if (type == PlanningItemType.Task && currentItemId.HasValue)
            {
                var hasChildren = await _context.PlanningItems
                    .AnyAsync(i => i.ParentId == currentItemId.Value);

                if (hasChildren)
                {
                    throw new InvalidOperationException(
                        "Impossible de convertir cet élément en tâche car il contient des sous-éléments."
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

        private static List<PlanningItem> OrderItemsByHierarchy(
            List<PlanningItem> items)
        {
            var orderedItems = new List<PlanningItem>();
            var visited = new HashSet<int>();

            void AddChildren(int? parentId)
            {
                var children = items
                    .Where(i => i.ParentId == parentId)
                    .OrderBy(i => i.SortOrder)
                    .ThenBy(i => i.Id)
                    .ToList();

                foreach (var child in children)
                {
                    if (!visited.Add(child.Id))
                        continue;

                    orderedItems.Add(child);
                    AddChildren(child.Id);
                }
            }

            AddChildren(parentId: null);

            // Sécurité pour ne pas masquer un ancien élément orphelin
            // ou une donnée historique incohérente.
            var remainingItems = items
                .Where(i => !visited.Contains(i.Id))
                .OrderBy(i => i.SortOrder)
                .ThenBy(i => i.Id)
                .ToList();

            foreach (var remainingItem in remainingItems)
            {
                if (!visited.Add(remainingItem.Id))
                    continue;

                orderedItems.Add(remainingItem);
                AddChildren(remainingItem.Id);
            }

            return orderedItems;
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