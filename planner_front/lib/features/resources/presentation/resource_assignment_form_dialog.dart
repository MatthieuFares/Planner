import 'package:flutter/material.dart';

import '../../tasks/data/task_model.dart';
import '../data/resource_assignment_model.dart';
import '../data/resource_group_model.dart';
import '../data/resource_model.dart';

enum AssignmentTargetType {
  resource,
  group,
}

class ResourceAssignmentFormDialog
    extends StatefulWidget {
  final List<PlannerTask> tasks;
  final List<Resource> resources;
  final List<ResourceGroup> groups;
  final List<ResourceAssignment> existingAssignments;
  final ResourceAssignment? assignment;

  const ResourceAssignmentFormDialog({
    super.key,
    required this.tasks,
    required this.resources,
    required this.groups,
    required this.existingAssignments,
    this.assignment,
  });

  @override
  State<ResourceAssignmentFormDialog> createState() =>
      _ResourceAssignmentFormDialogState();
}

class _ResourceAssignmentFormDialogState
    extends State<ResourceAssignmentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final _workloadController =
      TextEditingController(text: '0');

  final _allocationController =
      TextEditingController(text: '100');

  int? _taskId;
  int? _resourceId;
  int? _resourceGroupId;

  AssignmentTargetType _targetType =
      AssignmentTargetType.resource;

  bool get _isEditMode =>
      widget.assignment != null;

  List<ResourceGroup> get _nonEmptyGroups {
    return widget.groups
        .where((group) => group.members.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();

    final assignment = widget.assignment;

    if (assignment != null) {
      _taskId = _containsTask(assignment.taskId)
          ? assignment.taskId
          : null;

      _resourceId =
          assignment.resourceId != null &&
                  _containsResource(
                    assignment.resourceId!,
                  )
              ? assignment.resourceId
              : null;

      _resourceGroupId =
          assignment.resourceGroupId != null &&
                  _containsGroup(
                    assignment.resourceGroupId!,
                  )
              ? assignment.resourceGroupId
              : null;

      _workloadController.text =
          _formatEditableNumber(
        assignment.workloadHours,
      );

      _allocationController.text =
          assignment.allocationPercent.toString();

      _targetType =
          assignment.resourceGroupId != null
              ? AssignmentTargetType.group
              : AssignmentTargetType.resource;
    } else if (widget.resources.isEmpty &&
        _nonEmptyGroups.isNotEmpty) {
      _targetType = AssignmentTargetType.group;
    }
  }

  @override
  void dispose() {
    _workloadController.dispose();
    _allocationController.dispose();
    super.dispose();
  }

  bool _containsTask(int taskId) {
    return widget.tasks.any(
      (task) => task.id == taskId,
    );
  }

  bool _containsResource(int resourceId) {
    return widget.resources.any(
      (resource) => resource.id == resourceId,
    );
  }

  bool _containsGroup(int groupId) {
    return widget.groups.any(
      (group) => group.id == groupId,
    );
  }

  bool _isDuplicateResource(
    int resourceId,
  ) {
    if (_taskId == null) return false;

    return widget.existingAssignments.any(
      (assignment) =>
          assignment.id != widget.assignment?.id &&
          assignment.taskId == _taskId &&
          assignment.resourceId == resourceId,
    );
  }

  bool _isDuplicateGroup(
    int groupId,
  ) {
    if (_taskId == null) return false;

    return widget.existingAssignments.any(
      (assignment) =>
          assignment.id != widget.assignment?.id &&
          assignment.taskId == _taskId &&
          assignment.resourceGroupId == groupId,
    );
  }

  List<Resource> get _availableResources {
    return widget.resources.where((resource) {
      return resource.id == _resourceId ||
          !_isDuplicateResource(resource.id);
    }).toList();
  }

  List<ResourceGroup> get _availableGroups {
    return _nonEmptyGroups.where((group) {
      return group.id == _resourceGroupId ||
          !_isDuplicateGroup(group.id);
    }).toList();
  }

  void _onTaskChanged(int? taskId) {
    setState(() {
      _taskId = taskId;

      if (_resourceId != null &&
          _isDuplicateResource(_resourceId!)) {
        _resourceId = null;
      }

      if (_resourceGroupId != null &&
          _isDuplicateGroup(_resourceGroupId!)) {
        _resourceGroupId = null;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_taskId == null) {
      _showMessage(
        'Merci de sélectionner une tâche.',
      );
      return;
    }

    final isResourceTarget =
        _targetType ==
            AssignmentTargetType.resource;

    final isGroupTarget =
        _targetType == AssignmentTargetType.group;

    if (isResourceTarget &&
        _resourceId == null) {
      _showMessage(
        'Merci de sélectionner une ressource.',
      );
      return;
    }

    if (isGroupTarget &&
        _resourceGroupId == null) {
      _showMessage(
        'Merci de sélectionner un groupe.',
      );
      return;
    }

    final workload = double.parse(
      _workloadController.text
          .replaceAll(',', '.'),
    );

    final allocation = int.parse(
      _allocationController.text,
    );

    final resourceId =
        isResourceTarget ? _resourceId : null;

    final resourceGroupId =
        isGroupTarget ? _resourceGroupId : null;

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _taskLabel(PlannerTask task) {
    return '#${task.id} - ${task.title}';
  }

  String _resourceLabel(Resource resource) {
    return '${resource.name} '
        '(${_resourceTypeLabel(resource.type)})';
  }

  String _groupLabel(ResourceGroup group) {
    return '${group.name} '
        '(${group.members.length} membre(s))';
  }

  @override
  Widget build(BuildContext context) {
    final resources = _availableResources;
    final groups = _availableGroups;

    final canTargetResource =
        widget.resources.isNotEmpty;

    final canTargetGroup =
        _nonEmptyGroups.isNotEmpty;

    final hasAnyTarget =
        canTargetResource || canTargetGroup;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isEditMode
                ? Icons.edit_outlined
                : Icons.add_task_outlined,
          ),
          const SizedBox(width: 10),
          Text(
            _isEditMode
                ? 'Modifier l’assignation'
                : 'Nouvelle assignation',
          ),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _taskId,
                  decoration: const InputDecoration(
                    labelText: 'Tâche',
                    prefixIcon:
                        Icon(Icons.task_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: widget.tasks.map((task) {
                    return DropdownMenuItem<int>(
                      value: task.id,
                      child: Text(
                        _taskLabel(task),
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onTaskChanged,
                  validator: (value) {
                    if (value == null) {
                      return 'La tâche est obligatoire.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Cible de l’assignation',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge,
                ),
                const SizedBox(height: 7),
                SegmentedButton<
                    AssignmentTargetType>(
                  segments: [
                    ButtonSegment(
                      value:
                          AssignmentTargetType.resource,
                      enabled: canTargetResource,
                      icon:
                          const Icon(Icons.person_outline),
                      label:
                          const Text('Ressource'),
                    ),
                    ButtonSegment(
                      value: AssignmentTargetType.group,
                      enabled: canTargetGroup,
                      icon:
                          const Icon(Icons.groups_outlined),
                      label: const Text('Groupe'),
                    ),
                  ],
                  selected: {_targetType},
                  onSelectionChanged: hasAnyTarget
                      ? (selection) {
                          setState(() {
                            _targetType =
                                selection.first;

                            if (_targetType ==
                                AssignmentTargetType
                                    .resource) {
                              _resourceGroupId = null;
                            } else {
                              _resourceId = null;
                            }
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 14),
                if (_targetType ==
                    AssignmentTargetType.resource)
                  DropdownButtonFormField<int>(
                    initialValue: _resourceId,
                    decoration: InputDecoration(
                      labelText: 'Ressource',
                      prefixIcon:
                          const Icon(Icons.person),
                      border:
                          const OutlineInputBorder(),
                      helperText: _taskId == null
                          ? 'Choisis d’abord une tâche.'
                          : '${resources.length} '
                              'ressource(s) disponible(s)',
                    ),
                    items: resources.map((resource) {
                      return DropdownMenuItem<int>(
                        value: resource.id,
                        child: Text(
                          _resourceLabel(resource),
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged:
                        canTargetResource
                            ? (value) {
                                setState(() {
                                  _resourceId = value;
                                });
                              }
                            : null,
                    validator: (_) {
                      if (_targetType ==
                              AssignmentTargetType
                                  .resource &&
                          _resourceId == null) {
                        return 'La ressource est obligatoire.';
                      }

                      return null;
                    },
                  ),
                if (_targetType ==
                    AssignmentTargetType.group)
                  DropdownButtonFormField<int>(
                    initialValue: _resourceGroupId,
                    decoration: InputDecoration(
                      labelText:
                          'Groupe de ressources',
                      prefixIcon:
                          const Icon(Icons.groups),
                      border:
                          const OutlineInputBorder(),
                      helperText:
                          _nonEmptyGroups.isEmpty
                              ? 'Aucun groupe non vide.'
                              : '${groups.length} groupe(s) '
                                  'disponible(s)',
                    ),
                    items: groups.map((group) {
                      return DropdownMenuItem<int>(
                        value: group.id,
                        child: Text(
                          _groupLabel(group),
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: canTargetGroup
                        ? (value) {
                            setState(() {
                              _resourceGroupId = value;
                            });
                          }
                        : null,
                    validator: (_) {
                      if (_targetType ==
                              AssignmentTargetType
                                  .group &&
                          _resourceGroupId == null) {
                        return 'Le groupe est obligatoire.';
                      }

                      return null;
                    },
                  ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller:
                            _workloadController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Charge prévue',
                          suffixText: 'h',
                          prefixIcon:
                              Icon(Icons.schedule),
                          border:
                              OutlineInputBorder(),
                          helperText:
                              'Travail réel à réaliser.',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final workload =
                              double.tryParse(
                            (value ?? '')
                                .replaceAll(',', '.'),
                          );

                          if (workload == null ||
                              workload < 0) {
                            return 'Charge invalide.';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller:
                            _allocationController,
                        decoration:
                            const InputDecoration(
                          labelText: 'Allocation',
                          suffixText: '%',
                          prefixIcon:
                              Icon(Icons.percent),
                          border:
                              OutlineInputBorder(),
                          helperText:
                              'Intensité de mobilisation.',
                        ),
                        keyboardType:
                            TextInputType.number,
                        validator: (value) {
                          final allocation =
                              int.tryParse(
                            value ?? '',
                          );

                          if (allocation == null ||
                              allocation < 0 ||
                              allocation > 100) {
                            return 'Valeur entre 0 et 100.';
                          }

                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AssignmentRuleNotice(
                  targetType: _targetType,
                  group: _selectedGroup(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed:
              widget.tasks.isEmpty || !hasAnyTarget
                  ? null
                  : _submit,
          icon: Icon(
            _isEditMode
                ? Icons.save_outlined
                : Icons.add,
          ),
          label: Text(
            _isEditMode
                ? 'Enregistrer'
                : 'Créer',
          ),
        ),
      ],
    );
  }

  ResourceGroup? _selectedGroup() {
    if (_resourceGroupId == null) return null;

    for (final group in widget.groups) {
      if (group.id == _resourceGroupId) {
        return group;
      }
    }

    return null;
  }
}

class _AssignmentRuleNotice extends StatelessWidget {
  final AssignmentTargetType targetType;
  final ResourceGroup? group;

  const _AssignmentRuleNotice({
    required this.targetType,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final targetsGroup =
        targetType == AssignmentTargetType.group;

    final message = targetsGroup
        ? group == null
            ? 'La charge d’un groupe sera répartie '
                'également entre ses membres.'
            : 'La charge sera répartie entre '
                '${group!.members.length} membre(s).'
        : 'La charge sera affectée directement '
            'à la ressource sélectionnée.';

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            targetsGroup
                ? Icons.call_split_outlined
                : Icons.person_pin_outlined,
            size: 19,
            color:
                Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style:
                  Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

String _resourceTypeLabel(String type) {
  switch (type.toLowerCase()) {
    case 'team':
      return 'Équipe';
    case 'material':
      return 'Matériel';
    case 'person':
      return 'Personne';
    default:
      return type;
  }
}

String _formatEditableNumber(num value) {
  final doubleValue = value.toDouble();

  if (doubleValue == doubleValue.roundToDouble()) {
    return doubleValue.toInt().toString();
  }

  return doubleValue.toString();
}
