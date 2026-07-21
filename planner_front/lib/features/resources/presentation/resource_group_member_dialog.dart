import 'package:flutter/material.dart';

import '../data/resource_group_model.dart';
import '../data/resource_model.dart';

class ResourceGroupMemberDialog extends StatefulWidget {
  final List<ResourceGroup> groups;
  final List<Resource> resources;

  const ResourceGroupMemberDialog({
    super.key,
    required this.groups,
    required this.resources,
  });

  @override
  State<ResourceGroupMemberDialog> createState() =>
      _ResourceGroupMemberDialogState();
}

class _ResourceGroupMemberDialogState
    extends State<ResourceGroupMemberDialog> {
  int? _groupId;
  int? _resourceId;

  bool get _hasFixedGroup => widget.groups.length == 1;

  ResourceGroup? get _fixedGroup {
    if (!_hasFixedGroup) return null;

    return widget.groups.first;
  }

  @override
  void initState() {
    super.initState();

    if (_hasFixedGroup) {
      _groupId = widget.groups.first.id;
    }
  }

  void _submit() {
    if (_groupId == null || _resourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _groupId == null
                ? 'Merci de sélectionner un groupe et une ressource.'
                : 'Merci de sélectionner une ressource.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      ResourceGroupMemberRequest(
        resourceGroupId: _groupId!,
        resourceId: _resourceId!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixedGroup = _fixedGroup;

    return AlertDialog(
      title: Text(
        fixedGroup == null
            ? 'Ajouter une ressource à un groupe'
            : 'Ajouter une ressource à « ${fixedGroup.name} »',
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fixedGroup != null)
              _FixedGroupCard(group: fixedGroup)
            else
              DropdownButtonFormField<int>(
                initialValue: _groupId,
                decoration: const InputDecoration(
                  labelText: 'Groupe',
                  border: OutlineInputBorder(),
                ),
                items: widget.groups.map((group) {
                  return DropdownMenuItem<int>(
                    value: group.id,
                    child: Text(
                      '#${group.id} - ${group.name}',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _groupId = value;
                  });
                },
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _resourceId,
              decoration: const InputDecoration(
                labelText: 'Ressource',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_add_alt),
              ),
              items: widget.resources.map((resource) {
                return DropdownMenuItem<int>(
                  value: resource.id,
                  child: Text(
                    '#${resource.id} - ${resource.name}',
                  ),
                );
              }).toList(),
              onChanged: widget.resources.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _resourceId = value;
                      });
                    },
            ),
            if (widget.resources.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Aucune ressource disponible à ajouter.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed:
              widget.resources.isEmpty ? null : _submit,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _FixedGroupCard extends StatelessWidget {
  final ResourceGroup group;

  const _FixedGroupCard({
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.group_work_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Groupe sélectionné',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  group.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (group.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    group.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Chip(
            label: Text(
              '${group.members.length} membre(s)',
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
