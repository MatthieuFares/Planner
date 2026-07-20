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

class _ResourceGroupMemberDialogState extends State<ResourceGroupMemberDialog> {
  int? _groupId;
  int? _resourceId;

  void _submit() {
    if (_groupId == null || _resourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de sélectionner un groupe et une ressource.'),
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
    return AlertDialog(
      title: const Text('Ajouter une ressource à un groupe'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _groupId,
              decoration: const InputDecoration(
                labelText: 'Groupe',
                border: OutlineInputBorder(),
              ),
              items: widget.groups.map((group) {
                return DropdownMenuItem<int>(
                  value: group.id,
                  child: Text('#${group.id} - ${group.name}'),
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
              ),
              items: widget.resources.map((resource) {
                return DropdownMenuItem<int>(
                  value: resource.id,
                  child: Text('#${resource.id} - ${resource.name}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _resourceId = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}