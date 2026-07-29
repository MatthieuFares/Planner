import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../projects/data/project_access_api.dart';
import '../../projects/data/project_access_model.dart';
import '../../tasks/data/task_api.dart';
import '../../tasks/data/task_model.dart';
import '../data/resource_api.dart';
import '../data/resource_assignment_api.dart';
import '../data/resource_assignment_model.dart';
import '../data/resource_group_api.dart';
import '../data/resource_group_model.dart';
import '../data/resource_model.dart';
import 'resource_assignment_form_dialog.dart';

enum _AssignmentTargetFilter {
  all,
  resources,
  groups,
}

class ResourceAssignmentsTab extends StatefulWidget {
  final int projectId;

  const ResourceAssignmentsTab({
    super.key,
    required this.projectId,
  });

  @override
  State<ResourceAssignmentsTab> createState() =>
      _ResourceAssignmentsTabState();
}

class _ResourceAssignmentsTabState
    extends State<ResourceAssignmentsTab> {
  final TaskApi _taskApi = TaskApi();
  final ResourceApi _resourceApi = ResourceApi();
  final ResourceGroupApi _groupApi =
      ResourceGroupApi();

  final ProjectAccessApi _accessApi =
      ProjectAccessApi();

  final ResourceAssignmentApi _assignmentApi =
      ResourceAssignmentApi();

  final TextEditingController _searchController =
      TextEditingController();

  late Future<_AssignmentsData> _dataFuture;

  String _searchQuery = '';

  _AssignmentTargetFilter _targetFilter =
      _AssignmentTargetFilter.all;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<_AssignmentsData> _fetchData() async {
    final baseResults = await Future.wait<dynamic>([
      _accessApi.getProjectAccess(widget.projectId),
      _taskApi.getTasksByProject(widget.projectId),
      _assignmentApi.getAssignmentsByProject(
        widget.projectId,
      ),
    ]);

    final access =
        baseResults[0] as ProjectAccessModel;

    final tasks =
        List<PlannerTask>.from(baseResults[1] as List);

    final assignments =
        List<ResourceAssignment>.from(
      baseResults[2] as List,
    );

    var resources = <Resource>[];
    var hydratedGroups = <ResourceGroup>[];

    if (access.canReadResourceCatalog) {
      final catalogResults =
          await Future.wait<dynamic>([
        _resourceApi.getResources(),
        _groupApi.getGroups(),
      ]);

      resources =
          List<Resource>.from(catalogResults[0] as List);

      final groups =
          List<ResourceGroup>.from(
        catalogResults[1] as List,
      );

      hydratedGroups = await Future.wait(
        groups.map((group) async {
          final members =
              await _groupApi.getMembers(group.id);

          return ResourceGroup(
            id: group.id,
            name: group.name,
            description: group.description,
            members: members,
          );
        }),
      );
    }

    tasks.sort(
      (a, b) => a.title.toLowerCase().compareTo(
            b.title.toLowerCase(),
          ),
    );

    resources.sort(
      (a, b) => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
    );

    hydratedGroups.sort(
      (a, b) => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
    );

    assignments.sort((a, b) {
      final taskComparison =
          _taskNameByIdStatic(
        tasks,
        a.taskId,
      ).compareTo(
        _taskNameByIdStatic(
          tasks,
          b.taskId,
        ),
      );

      if (taskComparison != 0) {
        return taskComparison;
      }

      return a.targetLabel.compareTo(b.targetLabel);
    });

    return _AssignmentsData(
      access: access,
      tasks: tasks,
      resources: resources,
      groups: hydratedGroups,
      assignments: assignments,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loadData();
    });
  }

  Future<void> _createAssignment(
    _AssignmentsData data,
  ) async {
    final request =
        await showDialog<
            ResourceAssignmentCreateRequest>(
      context: context,
      builder: (context) {
        return ResourceAssignmentFormDialog(
          tasks: data.tasks,
          resources: data.resources,
          groups: data.groups,
          existingAssignments:
              data.assignments,
        );
      },
    );

    if (!mounted || request == null) return;

    try {
      await _assignmentApi.createAssignment(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Assignation créée avec succès.',
          ),
        ),
      );

      await _refresh();
    } catch (error) {
      _showAssignmentError(error);
    }
  }

  Future<void> _editAssignment(
    _AssignmentsData data,
    ResourceAssignment assignment,
  ) async {
    final request =
        await showDialog<
            ResourceAssignmentUpdateRequest>(
      context: context,
      builder: (context) {
        return ResourceAssignmentFormDialog(
          tasks: data.tasks,
          resources: data.resources,
          groups: data.groups,
          existingAssignments:
              data.assignments,
          assignment: assignment,
        );
      },
    );

    if (!mounted || request == null) return;

    try {
      await _assignmentApi.updateAssignment(
        assignment.id,
        request,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Assignation modifiée avec succès.',
          ),
        ),
      );

      await _refresh();
    } catch (error) {
      _showAssignmentError(error);
    }
  }

  Future<void> _deleteAssignment(
    _AssignmentsData data,
    ResourceAssignment assignment,
  ) async {
    final taskName = _taskNameById(
      data.tasks,
      assignment.taskId,
    );

    final targetName = _targetLabel(
      assignment,
      data.resources,
      data.groups,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text('Supprimer l’assignation'),
          content: Text(
            'Supprimer l’assignation suivante ?\n\n'
            '$taskName → $targetName\n'
            '${_formatNumber(assignment.workloadHours)} h '
            'à ${assignment.allocationPercent} %',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext)
                      .pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(dialogContext)
                      .pop(true),
              icon:
                  const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    try {
      await _assignmentApi.deleteAssignment(
        assignment.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Assignation supprimée avec succès.',
          ),
        ),
      );

      await _refresh();
    } catch (error) {
      _showAssignmentError(error);
    }
  }

  void _showAssignmentError(Object error) {
    if (!mounted) return;

    var message = 'Erreur assignation.';

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final responseText =
          error.response?.data?.toString() ?? '';

      if (responseText.contains('existe déjà')) {
        message =
            'Cette cible est déjà assignée '
            'à cette tâche.';
      } else if (
          responseText.contains('groupe vide')) {
        message =
            'Un groupe vide ne peut pas être '
            'assigné à une tâche.';
      } else if (statusCode == 400) {
        message = responseText.isNotEmpty
            ? responseText
            : 'Assignation invalide.';
      } else if (statusCode == 404) {
        message =
            'Assignation, tâche, ressource '
            'ou groupe introuvable.';
      } else if (statusCode == 500) {
        message =
            'Erreur serveur lors du traitement '
            'de l’assignation.';
      }
    } else {
      final raw = error.toString();

      if (raw.contains('existe déjà')) {
        message =
            'Cette cible est déjà assignée '
            'à cette tâche.';
      } else if (raw.contains('groupe vide')) {
        message =
            'Un groupe vide ne peut pas être '
            'assigné à une tâche.';
      } else if (raw.contains('400')) {
        message = 'Assignation invalide.';
      } else if (raw.contains('404')) {
        message =
            'Assignation, tâche, ressource '
            'ou groupe introuvable.';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _taskNameById(
    List<PlannerTask> tasks,
    int id,
  ) {
    return _taskNameByIdStatic(tasks, id);
  }

  String _targetLabel(
    ResourceAssignment assignment,
    List<Resource> resources,
    List<ResourceGroup> groups,
  ) {
    if (assignment.resourceGroupId != null) {
      if (assignment.resourceGroupName
              ?.isNotEmpty ==
          true) {
        return assignment.resourceGroupName!;
      }

      for (final group in groups) {
        if (group.id ==
            assignment.resourceGroupId) {
          return group.name;
        }
      }

      return 'Groupe '
          '#${assignment.resourceGroupId}';
    }

    if (assignment.resourceId != null) {
      if (assignment.resourceName
              ?.isNotEmpty ==
          true) {
        return assignment.resourceName!;
      }

      for (final resource in resources) {
        if (resource.id ==
            assignment.resourceId) {
          return resource.name;
        }
      }

      return 'Ressource '
          '#${assignment.resourceId}';
    }

    return 'Cible inconnue';
  }

  List<ResourceAssignment> _filterAssignments(
    _AssignmentsData data,
  ) {
    return data.assignments.where((assignment) {
      final targetMatches =
          switch (_targetFilter) {
        _AssignmentTargetFilter.all => true,
        _AssignmentTargetFilter.resources =>
          assignment.targetsResource,
        _AssignmentTargetFilter.groups =>
          assignment.targetsGroup,
      };

      if (!targetMatches) return false;

      if (_searchQuery.isEmpty) return true;

      final searchableText = [
        _taskNameById(
          data.tasks,
          assignment.taskId,
        ),
        _targetLabel(
          assignment,
          data.resources,
          data.groups,
        ),
        assignment.taskTitle ?? '',
      ].join(' ').toLowerCase();

      return searchableText.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AssignmentsData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return _AssignmentsErrorState(
            error: snapshot.error,
            onRetry: _refresh,
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return const Center(
            child: Text(
              'Aucune donnée assignation.',
            ),
          );
        }

        final visibleAssignments =
            _filterAssignments(data);

        final stats =
            _AssignmentStats.fromAssignments(
          data.assignments,
        );

        final groupedAssignments =
            _groupAssignmentsByTask(
          visibleAssignments,
        );

        final canCreate =
            data.access.canEditPlanning &&
                data.tasks.isNotEmpty &&
                (
                  data.resources.isNotEmpty ||
                  data.groups.any(
                    (group) =>
                        group.members.isNotEmpty,
                  )
                );

        return Column(
          children: [
            _AssignmentsHeader(
              assignmentCount:
                  data.assignments.length,
              canEdit:
                  data.access.canEditPlanning,
              canCreate: canCreate,
              onRefresh: _refresh,
              onCreate: () =>
                  _createAssignment(data),
            ),
            if (!data.access.canEditPlanning)
              const _ReadOnlyAssignmentsBanner(),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  16,
                ),
                children: [
                  _AssignmentsSummary(
                    stats: stats,
                  ),
                  const SizedBox(height: 14),
                  _AssignmentsFilters(
                    searchController:
                        _searchController,
                    searchQuery: _searchQuery,
                    targetFilter:
                        _targetFilter,
                    onSearchChanged: (value) {
                      setState(() {
                        _searchQuery = value
                            .trim()
                            .toLowerCase();
                      });
                    },
                    onClearSearch: () {
                      _searchController.clear();

                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    onTargetFilterChanged:
                        (filter) {
                      setState(() {
                        _targetFilter = filter;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  if (data.assignments.isEmpty)
                    _EmptyAssignmentsState(
                      canEdit:
                          data.access.canEditPlanning,
                      canCreate: canCreate,
                      onCreate: () =>
                          _createAssignment(data),
                    )
                  else if (
                      visibleAssignments.isEmpty)
                    const _NoAssignmentResult()
                  else
                    ...groupedAssignments.entries
                        .map((entry) {
                      final taskId = entry.key;
                      final assignments =
                          entry.value;

                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: _TaskAssignmentsCard(
                          taskName: _taskNameById(
                            data.tasks,
                            taskId,
                          ),
                          assignments:
                              assignments,
                          resources:
                              data.resources,
                          groups: data.groups,
                          targetLabel:
                              (assignment) =>
                                  _targetLabel(
                            assignment,
                            data.resources,
                            data.groups,
                          ),
                          canEdit:
                              data.access.canEditPlanning,
                          onEdit: (assignment) =>
                              _editAssignment(
                            data,
                            assignment,
                          ),
                          onDelete: (assignment) =>
                              _deleteAssignment(
                            data,
                            assignment,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Map<int, List<ResourceAssignment>>
      _groupAssignmentsByTask(
    List<ResourceAssignment> assignments,
  ) {
    final grouped =
        <int, List<ResourceAssignment>>{};

    for (final assignment in assignments) {
      grouped
          .putIfAbsent(
            assignment.taskId,
            () => <ResourceAssignment>[],
          )
          .add(assignment);
    }

    return grouped;
  }
}

class _AssignmentsHeader extends StatelessWidget {
  final int assignmentCount;
  final bool canEdit;
  final bool canCreate;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreate;

  const _AssignmentsHeader({
    required this.assignmentCount,
    required this.canEdit,
    required this.canCreate,
    required this.onRefresh,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.assignment_ind_outlined,
              color: Theme.of(context)
                  .colorScheme
                  .onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Assignations',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge,
                ),
                Text(
                  '$assignmentCount assignation(s) '
                  'sur le projet',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Rafraîchir'),
          ),
          if (canEdit) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: canCreate
                  ? 'Créer une assignation'
                  : 'Ajoute au moins une tâche et '
                      'une ressource ou un groupe non vide.',
              child: FilledButton.icon(
                onPressed:
                    canCreate ? onCreate : null,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Nouvelle assignation',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadOnlyAssignmentsBanner
    extends StatelessWidget {
  const _ReadOnlyAssignmentsBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        8,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .secondaryContainer
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 19,
              color: Theme.of(context)
                  .colorScheme
                  .onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mode lecture seule : vous pouvez consulter '
                'les assignations, mais pas les modifier.',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentsSummary extends StatelessWidget {
  final _AssignmentStats stats;

  const _AssignmentsSummary({
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _AssignmentMetricTile(
              icon:
                  Icons.assignment_ind_outlined,
              label: 'Assignations',
              value: '${stats.assignmentCount}',
            ),
            _AssignmentMetricTile(
              icon: Icons.person_outline,
              label: 'Vers ressources',
              value: '${stats.resourceCount}',
            ),
            _AssignmentMetricTile(
              icon: Icons.groups_outlined,
              label: 'Vers groupes',
              value: '${stats.groupCount}',
            ),
            _AssignmentMetricTile(
              icon: Icons.schedule_outlined,
              label: 'Charge totale',
              value:
                  '${_formatNumber(stats.totalWorkload)} h',
            ),
            _AssignmentMetricTile(
              icon: Icons.percent,
              label: 'Allocation moyenne',
              value:
                  '${_formatNumber(stats.averageAllocation)} %',
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentsFilters extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final _AssignmentTargetFilter targetFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_AssignmentTargetFilter>
      onTargetFilterChanged;

  const _AssignmentsFilters({
    required this.searchController,
    required this.searchQuery,
    required this.targetFilter,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onTargetFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment:
          WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 380,
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText:
                  'Rechercher une tâche ou une cible',
              prefixIcon:
                  const Icon(Icons.search),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip:
                          'Effacer la recherche',
                      onPressed: onClearSearch,
                      icon:
                          const Icon(Icons.clear),
                    ),
              border:
                  const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        SegmentedButton<
            _AssignmentTargetFilter>(
          segments: const [
            ButtonSegment(
              value:
                  _AssignmentTargetFilter.all,
              label: Text('Toutes'),
              icon: Icon(Icons.list_alt),
            ),
            ButtonSegment(
              value:
                  _AssignmentTargetFilter
                      .resources,
              label: Text('Ressources'),
              icon:
                  Icon(Icons.person_outline),
            ),
            ButtonSegment(
              value:
                  _AssignmentTargetFilter.groups,
              label: Text('Groupes'),
              icon:
                  Icon(Icons.groups_outlined),
            ),
          ],
          selected: {targetFilter},
          onSelectionChanged: (selection) {
            onTargetFilterChanged(
              selection.first,
            );
          },
        ),
      ],
    );
  }
}

class _TaskAssignmentsCard extends StatelessWidget {
  final String taskName;
  final List<ResourceAssignment> assignments;
  final bool canEdit;
  final List<Resource> resources;
  final List<ResourceGroup> groups;
  final String Function(
    ResourceAssignment assignment,
  ) targetLabel;

  final ValueChanged<ResourceAssignment> onEdit;
  final ValueChanged<ResourceAssignment> onDelete;

  const _TaskAssignmentsCard({
    required this.taskName,
    required this.assignments,
    required this.canEdit,
    required this.resources,
    required this.groups,
    required this.targetLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final totalWorkload = assignments.fold<double>(
      0,
      (sum, assignment) =>
          sum + assignment.workloadHours,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding:
            const EdgeInsets.fromLTRB(14, 7, 10, 7),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.65),
            borderRadius:
                BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            '${assignments.length}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          taskName,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _SmallAssignmentChip(
                icon:
                    Icons.assignment_ind_outlined,
                text:
                    '${assignments.length} assignation(s)',
              ),
              _SmallAssignmentChip(
                icon: Icons.schedule_outlined,
                text:
                    '${_formatNumber(totalWorkload)} h',
              ),
            ],
          ),
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          const Divider(),
          ...assignments.map((assignment) {
            return Padding(
              padding:
                  const EdgeInsets.only(bottom: 7),
              child: _AssignmentTile(
                assignment: assignment,
                canEdit: canEdit,
                targetName:
                    targetLabel(assignment),
                estimatedCost:
                    _estimateAssignmentCost(
                  assignment,
                  resources,
                  groups,
                ),
                groupMemberCount:
                    _groupMemberCount(
                  assignment,
                  groups,
                ),
                onEdit: () =>
                    onEdit(assignment),
                onDelete: () =>
                    onDelete(assignment),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  final ResourceAssignment assignment;
  final bool canEdit;
  final String targetName;
  final double? estimatedCost;
  final int? groupMemberCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AssignmentTile({
    required this.assignment,
    required this.canEdit,
    required this.targetName,
    required this.estimatedCost,
    required this.groupMemberCount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final targetsGroup =
        assignment.targetsGroup;

    return Material(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.30),
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.10),
            borderRadius:
                BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            targetsGroup
                ? Icons.groups_outlined
                : Icons.person_outline,
            color:
                Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          targetName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _SmallAssignmentChip(
                icon: Icons.schedule,
                text:
                    '${_formatNumber(assignment.workloadHours)} h',
              ),
              _SmallAssignmentChip(
                icon: Icons.percent,
                text:
                    '${assignment.allocationPercent} %',
              ),
              if (targetsGroup &&
                  groupMemberCount != null)
                _SmallAssignmentChip(
                  icon:
                      Icons.call_split_outlined,
                  text:
                      '$groupMemberCount membre(s)',
                ),
              if (estimatedCost != null)
                _SmallAssignmentChip(
                  icon: Icons.euro_outlined,
                  text:
                      '${_formatNumber(estimatedCost!)} € estimés',
                ),
            ],
          ),
        ),
        trailing: canEdit
            ? SizedBox(
                width: 104,
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Modifier',
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_outlined,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Supprimer',
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

class _AssignmentMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AssignmentMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 205,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color:
                Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallAssignmentChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallAssignmentChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style:
                const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _AssignmentsErrorState
    extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRetry;

  const _AssignmentsErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 42,
                color: Theme.of(context)
                    .colorScheme
                    .error,
              ),
              const SizedBox(height: 10),
              const Text(
                'Impossible de charger '
                'les assignations.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                error?.toString() ??
                    'Erreur inconnue',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAssignmentsState extends StatelessWidget {
  final bool canEdit;
  final bool canCreate;
  final VoidCallback onCreate;

  const _EmptyAssignmentsState({
    required this.canEdit,
    required this.canCreate,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(
              Icons.assignment_ind_outlined,
              size: 46,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune assignation',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              !canEdit
                  ? 'Aucune assignation à afficher. '
                      'Votre accès à ce projet est en lecture seule.'
                  : canCreate
                      ? 'Associe une tâche à une ressource '
                          'ou à un groupe.'
                      : 'Ajoute une tâche et au moins '
                          'une ressource ou un groupe non vide.',
              textAlign: TextAlign.center,
            ),
            if (canCreate) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Créer la première assignation',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoAssignmentResult extends StatelessWidget {
  const _NoAssignmentResult();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off),
            SizedBox(width: 9),
            Text(
              'Aucune assignation ne correspond.',
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentsData {
  final ProjectAccessModel access;
  final List<PlannerTask> tasks;
  final List<Resource> resources;
  final List<ResourceGroup> groups;
  final List<ResourceAssignment> assignments;

  const _AssignmentsData({
    required this.access,
    required this.tasks,
    required this.resources,
    required this.groups,
    required this.assignments,
  });
}

class _AssignmentStats {
  final int assignmentCount;
  final int resourceCount;
  final int groupCount;
  final double totalWorkload;
  final double averageAllocation;

  const _AssignmentStats({
    required this.assignmentCount,
    required this.resourceCount,
    required this.groupCount,
    required this.totalWorkload,
    required this.averageAllocation,
  });

  factory _AssignmentStats.fromAssignments(
    List<ResourceAssignment> assignments,
  ) {
    return _AssignmentStats(
      assignmentCount: assignments.length,
      resourceCount: assignments
          .where(
            (assignment) =>
                assignment.targetsResource,
          )
          .length,
      groupCount: assignments
          .where(
            (assignment) =>
                assignment.targetsGroup,
          )
          .length,
      totalWorkload: assignments.fold<double>(
        0,
        (sum, assignment) =>
            sum + assignment.workloadHours,
      ),
      averageAllocation: assignments.isEmpty
          ? 0
          : assignments.fold<double>(
                0,
                (sum, assignment) =>
                    sum +
                    assignment.allocationPercent,
              ) /
              assignments.length,
    );
  }
}

String _taskNameByIdStatic(
  List<PlannerTask> tasks,
  int id,
) {
  for (final task in tasks) {
    if (task.id == id) {
      return task.title;
    }
  }

  return 'Tâche #$id';
}

int? _groupMemberCount(
  ResourceAssignment assignment,
  List<ResourceGroup> groups,
) {
  if (assignment.resourceGroupId == null) {
    return null;
  }

  for (final group in groups) {
    if (group.id ==
        assignment.resourceGroupId) {
      return group.members.length;
    }
  }

  return null;
}

double? _estimateAssignmentCost(
  ResourceAssignment assignment,
  List<Resource> resources,
  List<ResourceGroup> groups,
) {
  if (assignment.resourceId != null) {
    for (final resource in resources) {
      if (resource.id == assignment.resourceId) {
        return assignment.workloadHours *
            resource.costPerHour;
      }
    }

    return null;
  }

  if (assignment.resourceGroupId != null) {
    for (final group in groups) {
      if (group.id !=
          assignment.resourceGroupId) {
        continue;
      }

      if (group.members.isEmpty) {
        return 0;
      }

      final workloadPerMember =
          assignment.workloadHours /
              group.members.length;

      return group.members.fold<double>(
        0,
        (sum, member) =>
            sum +
            workloadPerMember *
                member.costPerHour,
      );
    }
  }

  return null;
}

String _formatNumber(num value) {
  final doubleValue = value.toDouble();

  if (doubleValue ==
      doubleValue.roundToDouble()) {
    return doubleValue.toInt().toString();
  }

  return doubleValue.toStringAsFixed(1);
}
