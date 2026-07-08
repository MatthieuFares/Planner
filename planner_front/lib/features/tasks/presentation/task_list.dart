import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/task_api.dart';
import '../data/task_model.dart';

import '../../dependencies/data/dependency_api.dart';
import '../../dependencies/data/dependency_model.dart';
import '../../resources/data/resource_assignment_api.dart';
import '../../resources/data/resource_assignment_model.dart';

import 'task_form_dialog.dart';
import 'task_form_result.dart';
import 'task_edit_dialog.dart';

class TaskList extends StatefulWidget {
  final int projectId;

  const TaskList({
    super.key,
    required this.projectId,
  });

  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  final TaskApi _taskApi = TaskApi();
  final DependencyApi _dependencyApi = DependencyApi();
  final ResourceAssignmentApi _resourceAssignmentApi = ResourceAssignmentApi();

  late Future<List<PlannerTask>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    _tasksFuture = _taskApi.getTasksByProject(widget.projectId);
  }

  Future<void> _refreshTasks() async {
    setState(() {
      _loadTasks();
    });
  }

  Future<void> _createTaskRelatedData({
    required PlannerTask createdTask,
    required TaskFormResult result,
  }) async {
    if (result.hasPredecessor) {
      await _dependencyApi.createDependency(
        DependencyCreateRequest(
          predecessorId: result.predecessorTaskId!,
          successorId: createdTask.id,
          type: result.dependencyType,
          offsetDays: result.offsetDays,
        ),
      );
    }

    if (result.hasAssignment) {
      await _resourceAssignmentApi.createAssignment(
        ResourceAssignmentCreateRequest(
          taskId: createdTask.id,
          resourceId: result.resourceId,
          resourceGroupId: null,
          workloadHours: result.workloadHours!,
          allocationPercent: result.allocationPercent,
        ),
      );
    }
  }

  Future<void> _openCreateTaskDialog() async {
    final result = await showDialog<TaskFormResult>(
      context: context,
      builder: (context) {
        return TaskFormDialog(projectId: widget.projectId);
      },
    );

    if (result == null) return;

    try {
      final createdTask = await _taskApi.createTask(result.taskRequest);

      await _createTaskRelatedData(
        createdTask: createdTask,
        result: result,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _buildCreateSuccessMessage(result),
          ),
        ),
      );

      await _refreshTasks();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _buildCreateSuccessMessage(TaskFormResult result) {
    final details = <String>[];

    if (result.hasPredecessor) {
      details.add('prédécesseur ajouté');
    }

    if (result.hasAssignment) {
      details.add('assignation ajoutée');
    }

    if (details.isEmpty) {
      return 'Tâche créée avec succès.';
    }

    return 'Tâche créée avec succès (${details.join(', ')}).';
  }

  Future<void> _deleteTask(PlannerTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la tâche'),
          content: Text('Voulez-vous vraiment supprimer "${task.title}" ?'),
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
      await _taskApi.deleteTask(task.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tâche supprimée avec succès.'),
        ),
      );

      await _refreshTasks();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatTaskDeleteError(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openEditTaskDialog(PlannerTask task) async {
    final request = await showDialog<TaskUpdateRequest>(
      context: context,
      builder: (context) {
        return TaskEditDialog(task: task);
      },
    );

    if (request == null) return;

    try {
      await _taskApi.updateTask(task.id, request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tâche modifiée avec succès.'),
        ),
      );

      await _refreshTasks();
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

  String formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TaskToolbar(
          onRefresh: _refreshTasks,
          onCreateTask: _openCreateTaskDialog,
        ),
        Expanded(
          child: FutureBuilder<List<PlannerTask>>(
            future: _tasksFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Erreur lors du chargement des tâches : ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final tasks = snapshot.data ?? [];

              if (tasks.isEmpty) {
                return const Center(
                  child: Text('Aucune tâche pour ce projet.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final task = tasks[index];

                  return Card(
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color:
                                    task.isDone ? Colors.green.shade700 : null,
                                decoration: task.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (task.isDone)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Chip(
                                label: Text('Terminée'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        'Début : ${formatDate(task.startDate)} | '
                        'Fin : ${formatDate(task.endDate)} | '
                        'Durée : ${task.duration ?? '-'}j | '
                        'Progression : ${task.progressPercent}%'
                        '${task.deadline == null ? '' : ' | Deadline : ${formatDate(task.deadline)}'}',
                      ),
                      trailing: SizedBox(
                        width: 240,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  task.isLate
                                      ? 'En retard'
                                      : task.isCritical == true
                                          ? 'Critique'
                                          : 'Non critique',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: task.isLate
                                        ? Colors.red
                                        : task.isCritical == true
                                            ? Colors.orange.shade800
                                            : Colors.grey,
                                  ),
                                ),
                                Text('Float : ${task.floatValue ?? '-'}'),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Modifier',
                              onPressed: () => _openEditTaskDialog(task),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: () => _deleteTask(task),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTaskDeleteError(Object error) {
    final raw = error.toString();

    if (raw.contains('dépendance') ||
        raw.contains('dependency') ||
        raw.contains('Dependency')) {
      return 'Impossible de supprimer cette tâche : elle est liée à une ou plusieurs dépendances. Supprimez d’abord les dépendances associées.';
    }

    if (raw.contains('assignation') ||
        raw.contains('ressource') ||
        raw.contains('ResourceAssignment')) {
      return 'Impossible de supprimer cette tâche : elle possède une ou plusieurs assignations de ressources. Supprimez d’abord les assignations associées.';
    }

    if (raw.contains('400') || raw.contains('500')) {
      return 'Impossible de supprimer cette tâche : elle est encore liée à des données de planning.';
    }

    if (raw.contains('404')) {
      return 'Impossible de supprimer cette tâche : elle est introuvable.';
    }

    return 'Erreur lors de la suppression de la tâche.';
  }
}

class _TaskToolbar extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onCreateTask;

  const _TaskToolbar({
    required this.onRefresh,
    required this.onCreateTask,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: onCreateTask,
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle tâche'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Rafraîchir'),
          ),
        ],
      ),
    );
  }
}