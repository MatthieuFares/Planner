import 'package:flutter/material.dart';

import '../../tasks/data/task_api.dart';
import '../../tasks/data/task_model.dart';
import '../data/resource_api.dart';
import '../data/resource_assignment_api.dart';
import '../data/resource_assignment_model.dart';
import '../data/resource_group_api.dart';
import '../data/resource_group_model.dart';
import '../data/resource_model.dart';
import 'resource_assignment_form_dialog.dart';

class ResourceAssignmentsTab extends StatefulWidget {
  final int projectId;

  const ResourceAssignmentsTab({
    super.key,
    required this.projectId,
  });

  @override
  State<ResourceAssignmentsTab> createState() => _ResourceAssignmentsTabState();
}

class _ResourceAssignmentsTabState extends State<ResourceAssignmentsTab> {
  final TaskApi _taskApi = TaskApi();
  final ResourceApi _resourceApi = ResourceApi();
  final ResourceGroupApi _groupApi = ResourceGroupApi();
  final ResourceAssignmentApi _assignmentApi = ResourceAssignmentApi();

  late Future<_AssignmentsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<_AssignmentsData> _fetchData() async {
    final tasks = await _taskApi.getTasksByProject(widget.projectId);
    final resources = await _resourceApi.getResources();
    final groups = await _groupApi.getGroups();

    final Map<int, ResourceAssignment> assignmentsById = {};

    for (final task in tasks) {
      final taskAssignments = await _assignmentApi.getAssignmentsByTask(task.id);

      for (final assignment in taskAssignments) {
        assignmentsById[assignment.id] = assignment;
      }
    }

    final assignments = assignmentsById.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return _AssignmentsData(
      tasks: tasks,
      resources: resources,
      groups: groups,
      assignments: assignments,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loadData();
    });
  }

  String _taskNameById(List<PlannerTask> tasks, int id) {
    final matches = tasks.where((task) => task.id == id);

    if (matches.isEmpty) return 'Tâche #$id';

    return matches.first.title;
  }

  String _targetLabel(
    ResourceAssignment assignment,
    List<Resource> resources,
    List<ResourceGroup> groups,
  ) {
    if (assignment.resourceGroupId != null) {
      if (assignment.resourceGroupName != null &&
          assignment.resourceGroupName!.isNotEmpty) {
        return 'Groupe : ${assignment.resourceGroupName}';
      }

      final matches = groups.where(
        (group) => group.id == assignment.resourceGroupId,
      );

      if (matches.isNotEmpty) {
        return 'Groupe : ${matches.first.name}';
      }

      return 'Groupe #${assignment.resourceGroupId}';
    }

    if (assignment.resourceId != null) {
      if (assignment.resourceName != null &&
          assignment.resourceName!.isNotEmpty) {
        return assignment.resourceName!;
      }

      final matches = resources.where(
        (resource) => resource.id == assignment.resourceId,
      );

      if (matches.isNotEmpty) {
        return matches.first.name;
      }

      return 'Ressource #${assignment.resourceId}';
    }

    return 'Cible inconnue';
  }

  Future<void> _createAssignment(_AssignmentsData data) async {
    final request = await showDialog<ResourceAssignmentCreateRequest>(
      context: context,
      builder: (context) {
        return ResourceAssignmentFormDialog(
          tasks: data.tasks,
          resources: data.resources,
          groups: data.groups,
        );
      },
    );

    if (request == null) return;

    try {
      await _assignmentApi.createAssignment(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignation créée avec succès.'),
        ),
      );

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatAssignmentError(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editAssignment(
    _AssignmentsData data,
    ResourceAssignment assignment,
  ) async {
    final request = await showDialog<ResourceAssignmentUpdateRequest>(
      context: context,
      builder: (context) {
        return ResourceAssignmentFormDialog(
          tasks: data.tasks,
          resources: data.resources,
          groups: data.groups,
          assignment: assignment,
        );
      },
    );

    if (request == null) return;

    try {
      await _assignmentApi.updateAssignment(assignment.id, request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignation modifiée avec succès.'),
        ),
      );

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatAssignmentError(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteAssignment(ResourceAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer assignation'),
          content: Text(
            'Voulez-vous vraiment supprimer cette assignation #${assignment.id} ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _assignmentApi.deleteAssignment(assignment.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignation supprimée avec succès.'),
        ),
      );

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatAssignmentError(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatAssignmentError(Object error) {
    final raw = error.toString();

    if (raw.contains('400')) {
      return 'Assignation invalide : choisis soit une ressource, soit un groupe.';
    }

    if (raw.contains('404')) {
      return 'Assignation, tâche, ressource ou groupe introuvable.';
    }

    if (raw.contains('500')) {
      return 'Erreur serveur lors du traitement de l’assignation.';
    }

    return 'Erreur assignation.';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AssignmentsData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur assignations : ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return const Center(
            child: Text('Aucune donnée assignation.'),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Assignations',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rafraîchir'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _createAssignment(data),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle assignation'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: data.assignments.isEmpty
                  ? const Center(
                      child: Text('Aucune assignation pour ce projet.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: data.assignments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final assignment = data.assignments[index];

                        final taskName = _taskNameById(
                          data.tasks,
                          assignment.taskId,
                        );

                        final targetName = _targetLabel(
                          assignment,
                          data.resources,
                          data.groups,
                        );

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              assignment.targetsGroup
                                  ? Icons.groups_outlined
                                  : Icons.assignment_ind_outlined,
                            ),
                            title: Text('$taskName → $targetName'),
                            subtitle: Text(
                              'Charge : ${assignment.workloadHours}h | '
                              'Allocation : ${assignment.allocationPercent}%',
                            ),
                            trailing: SizedBox(
                              width: 104,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: 'Modifier',
                                    onPressed: () => _editAssignment(
                                      data,
                                      assignment,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    onPressed: () =>
                                        _deleteAssignment(assignment),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AssignmentsData {
  final List<PlannerTask> tasks;
  final List<Resource> resources;
  final List<ResourceGroup> groups;
  final List<ResourceAssignment> assignments;

  _AssignmentsData({
    required this.tasks,
    required this.resources,
    required this.groups,
    required this.assignments,
  });
}