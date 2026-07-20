import 'package:flutter/material.dart';

import '../../tasks/data/task_model.dart';
import '../data/resource_assignment_model.dart';
import '../data/resource_group_model.dart';
import '../data/resource_model.dart';

enum AssignmentTargetType {
  resource,
  group,
}

class ResourceAssignmentFormDialog extends StatefulWidget {
  final List<PlannerTask> tasks;
  final List<Resource> resources;
  final List<ResourceGroup> groups;
  final ResourceAssignment? assignment;

  const ResourceAssignmentFormDialog({
    super.key,
    required this.tasks,
    required this.resources,
    required this.groups,
    this.assignment,
  });

  @override
  State<ResourceAssignmentFormDialog> createState() =>
      _ResourceAssignmentFormDialogState();
}

class _ResourceAssignmentFormDialogState
    extends State<ResourceAssignmentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final _workloadController = TextEditingController(text: '0');
  final _allocationController = TextEditingController(text: '100');

  int? _taskId;
  int? _resourceId;
  int? _resourceGroupId;

  AssignmentTargetType _targetType = AssignmentTargetType.resource;

  bool get _isEditMode => widget.assignment != null;

  @override
  void initState() {
    super.initState();

    final assignment = widget.assignment;

    if (assignment != null) {
      _taskId = assignment.taskId;
      _resourceId = assignment.resourceId;
      _resourceGroupId = assignment.resourceGroupId;
      _workloadController.text = assignment.workloadHours.toString();
      _allocationController.text = assignment.allocationPercent.toString();

      _targetType = assignment.resourceGroupId != null
          ? AssignmentTargetType.group
          : AssignmentTargetType.resource;
    }
  }

  @override
  void dispose() {
    _workloadController.dispose();
    _allocationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_taskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de sélectionner une tâche.'),
        ),
      );
      return;
    }

    final isResourceTarget = _targetType == AssignmentTargetType.resource;
    final isGroupTarget = _targetType == AssignmentTargetType.group;

    if (isResourceTarget && _resourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de sélectionner une ressource.'),
        ),
      );
      return;
    }

    if (isGroupTarget && _resourceGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de sélectionner un groupe.'),
        ),
      );
      return;
    }

    final workload = double.parse(
      _workloadController.text.replaceAll(',', '.'),
    );

    final allocation = int.parse(_allocationController.text);

    final resourceId = isResourceTarget ? _resourceId : null;
    final resourceGroupId = isGroupTarget ? _resourceGroupId : null;

    if (_isEditMode) {
      Navigator.of(context).pop(
        ResourceAssignmentUpdateRequest(
          taskId: _taskId!,
          resourceId: resourceId,
          resourceGroupId: resourceGroupId,
          workloadHours: workload,
          allocationPercent: allocation,
        ),
      );
    } else {
      Navigator.of(context).pop(
        ResourceAssignmentCreateRequest(
          taskId: _taskId!,
          resourceId: resourceId,
          resourceGroupId: resourceGroupId,
          workloadHours: workload,
          allocationPercent: allocation,
        ),
      );
    }
  }

  String _taskLabel(PlannerTask task) {
    return '#${task.id} - ${task.title}';
  }

  String _resourceLabel(Resource resource) {
    return '#${resource.id} - ${resource.name} (${resource.type})';
  }

  String _groupLabel(ResourceGroup group) {
    return '#${group.id} - ${group.name}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Modifier assignation' : 'Nouvelle assignation'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _taskId,
                  decoration: const InputDecoration(
                    labelText: 'Tâche',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.tasks.map((task) {
                    return DropdownMenuItem<int>(
                      value: task.id,
                      child: Text(_taskLabel(task)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _taskId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'La tâche est obligatoire.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Type de cible',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 4),

                SegmentedButton<AssignmentTargetType>(
                  segments: const [
                    ButtonSegment(
                      value: AssignmentTargetType.resource,
                      icon: Icon(Icons.person_outline),
                      label: Text('Ressource'),
                    ),
                    ButtonSegment(
                      value: AssignmentTargetType.group,
                      icon: Icon(Icons.groups_outlined),
                      label: Text('Groupe'),
                    ),
                  ],
                  selected: {_targetType},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _targetType = selection.first;

                      if (_targetType == AssignmentTargetType.resource) {
                        _resourceGroupId = null;
                      } else {
                        _resourceId = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),

                if (_targetType == AssignmentTargetType.resource)
                  DropdownButtonFormField<int>(
                    initialValue: _resourceId,
                    decoration: const InputDecoration(
                      labelText: 'Ressource',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.resources.map((resource) {
                      return DropdownMenuItem<int>(
                        value: resource.id,
                        child: Text(_resourceLabel(resource)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _resourceId = value;
                      });
                    },
                    validator: (_) {
                      if (_targetType == AssignmentTargetType.resource &&
                          _resourceId == null) {
                        return 'La ressource est obligatoire.';
                      }

                      return null;
                    },
                  ),

                if (_targetType == AssignmentTargetType.group)
                  DropdownButtonFormField<int>(
                    initialValue: _resourceGroupId,
                    decoration: const InputDecoration(
                      labelText: 'Groupe de ressources',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.groups.map((group) {
                      return DropdownMenuItem<int>(
                        value: group.id,
                        child: Text(_groupLabel(group)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _resourceGroupId = value;
                      });
                    },
                    validator: (_) {
                      if (_targetType == AssignmentTargetType.group &&
                          _resourceGroupId == null) {
                        return 'Le groupe est obligatoire.';
                      }

                      return null;
                    },
                  ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _workloadController,
                  decoration: const InputDecoration(
                    labelText: 'Charge prévue en heures',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final workload = double.tryParse(
                      (value ?? '').replaceAll(',', '.'),
                    );

                    if (workload == null || workload < 0) {
                      return 'Charge invalide.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _allocationController,
                  decoration: const InputDecoration(
                    labelText: 'Allocation %',
                    border: OutlineInputBorder(),
                    helperText: 'Exemple : 100 pour temps plein',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final allocation = int.tryParse(value ?? '');

                    if (allocation == null || allocation < 0) {
                      return 'Allocation invalide.';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditMode ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }
}