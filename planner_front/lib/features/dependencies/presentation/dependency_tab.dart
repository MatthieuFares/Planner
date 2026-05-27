import 'package:flutter/material.dart';

import '../../tasks/data/task_api.dart';
import '../../tasks/data/task_model.dart';
import '../data/dependency_api.dart';
import '../data/dependency_model.dart';
import 'dependency_form_dialog.dart';

class DependenciesTab extends StatefulWidget {
  final int projectId;

  const DependenciesTab({
    super.key,
    required this.projectId,
  });

  @override
  State<DependenciesTab> createState() => _DependenciesTabState();
}

class _DependenciesTabState extends State<DependenciesTab> {
  final DependencyApi _dependencyApi = DependencyApi();
  final TaskApi _taskApi = TaskApi();

  late Future<_DependenciesData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<_DependenciesData> _fetchData() async {
  final tasks = await _taskApi.getTasksByProject(widget.projectId);

  if (tasks.isEmpty) {
    return _DependenciesData(
      tasks: tasks,
      dependencies: [],
    );
  }

  final Map<int, TaskDependency> dependenciesById = {};

    for (final task in tasks) {
      final taskDependencies =
          await _dependencyApi.getDependenciesByTask(task.id);

      for (final dependency in taskDependencies) {
        dependenciesById[dependency.id] = dependency;
      }
    }

    final dependencies = dependenciesById.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return _DependenciesData(
      tasks: tasks,
      dependencies: dependencies,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loadData();
    });
  }

  String _taskNameById(List<PlannerTask> tasks, int id) {
    final matchingTasks = tasks.where((task) => task.id == id);

    if (matchingTasks.isEmpty) {
      return 'Tâche #$id';
    }

    return matchingTasks.first.title;
  }

  Future<void> _createDependency(List<PlannerTask> tasks) async {
    final request = await showDialog<DependencyCreateRequest>(
      context: context,
      builder: (context) {
        return DependencyFormDialog(tasks: tasks);
      },
    );

    if (request == null) return;

    try {
      await _dependencyApi.createDependency(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dépendance créée avec succès.'),
        ),
      );

      await _refresh();
    } catch (error) {
        if (!mounted) return;

        final message = _formatDependencyError(error);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
  }

  Future<void> _editDependency(
    List<PlannerTask> tasks,
    TaskDependency dependency,
  ) async {
    final request = await showDialog<DependencyUpdateRequest>(
      context: context,
      builder: (context) {
        return DependencyFormDialog(
          tasks: tasks,
          dependency: dependency,
        );
      },
    );

    if (request == null) return;

    try {
      await _dependencyApi.updateDependency(dependency.id, request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dépendance modifiée avec succès.'),
        ),
      );

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la modification : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteDependency(TaskDependency dependency) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la dépendance'),
          content: Text(
            'Voulez-vous vraiment supprimer la dépendance #${dependency.id} ?',
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
      await _dependencyApi.deleteDependency(dependency.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dépendance supprimée avec succès.'),
        ),
      );

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DependenciesData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur dépendances : ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return const Center(
            child: Text('Aucune donnée dépendance.'),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Dépendances',
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
                    onPressed: () => _createDependency(data.tasks),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle dépendance'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: data.dependencies.isEmpty
                  ? const Center(
                      child: Text('Aucune dépendance pour ce projet.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: data.dependencies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final dependency = data.dependencies[index];

                        final predecessorName = _taskNameById(
                          data.tasks,
                          dependency.predecessorId,
                        );

                        final successorName = _taskNameById(
                          data.tasks,
                          dependency.successorId,
                        );

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.account_tree_outlined),
                            title: Text(
                              '$predecessorName → $successorName',
                            ),
                            subtitle: Text(
                              'Type : ${dependency.type} | Offset : ${dependency.offsetDays}j',
                            ),
                            trailing: SizedBox(
                              width: 104,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: 'Modifier',
                                    onPressed: () => _editDependency(
                                      data.tasks,
                                      dependency,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    onPressed: () =>
                                        _deleteDependency(dependency),
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

  String _formatDependencyError(Object error) {
    final raw = error.toString();

    if (raw.contains('400')) {
      return 'Impossible de créer la dépendance : elle existe déjà ou elle est invalide.';
    }

    if (raw.contains('cycle') || raw.contains('Cycle')) {
      return 'Impossible de créer la dépendance : elle créerait un cycle.';
    }

    if (raw.contains('404')) {
      return 'Impossible de créer la dépendance : une des tâches est introuvable.';
    }

    return 'Erreur dépendance : $error';
  }
}

class _DependenciesData {
  final List<PlannerTask> tasks;
  final List<TaskDependency> dependencies;

  _DependenciesData({
    required this.tasks,
    required this.dependencies,
  });
}