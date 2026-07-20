import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../data/resource_api.dart';
import '../data/resource_group_api.dart';
import '../data/resource_group_model.dart';
import '../data/resource_model.dart';
import 'resource_group_form_dialog.dart';
import 'resource_group_member_dialog.dart';

class ResourceGroupsTab extends StatefulWidget {
  const ResourceGroupsTab({super.key});

  @override
  State<ResourceGroupsTab> createState() => _ResourceGroupsTabState();
}

class _ResourceGroupsTabState extends State<ResourceGroupsTab> {
  final ResourceGroupApi _groupApi = ResourceGroupApi();
  final ResourceApi _resourceApi = ResourceApi();

  late Future<_ResourceGroupsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<_ResourceGroupsData> _fetchData() async {
    final groups = await _groupApi.getGroups();
    final resources = await _resourceApi.getResources();

    return _ResourceGroupsData(
      groups: groups,
      resources: resources,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loadData();
    });
  }

  Future<void> _createGroup() async {
    final request = await showDialog<ResourceGroupCreateRequest>(
      context: context,
      builder: (_) => const ResourceGroupFormDialog(),
    );

    if (request == null) return;

    try {
      await _groupApi.createGroup(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Groupe créé avec succès.')),
      );

      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _editGroup(ResourceGroup group) async {
    final request = await showDialog<ResourceGroupUpdateRequest>(
      context: context,
      builder: (_) => ResourceGroupFormDialog(group: group),
    );

    if (request == null) return;

    try {
      await _groupApi.updateGroup(group.id, request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Groupe modifié avec succès.')),
      );

      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteGroup(ResourceGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Supprimer le groupe'),
          content: Text(
            'Voulez-vous vraiment supprimer "${group.name}" ?\n\n'
            'Un groupe contenant des membres ne peut généralement pas être supprimé.',
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
      await _groupApi.deleteGroup(group.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Groupe supprimé avec succès.')),
      );

      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _addMemberToGroup(
    ResourceGroup group,
    List<Resource> resources,
  ) async {
    final request = await showDialog<ResourceGroupMemberRequest>(
      context: context,
      builder: (_) => ResourceGroupMemberDialog(
        groups: [group],
        resources: resources,
      ),
    );

    if (request == null) return;

    try {
      await _groupApi.addMember(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membre ajouté au groupe.')),
      );

      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _removeMember(
    ResourceGroup group,
    ResourceGroupMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Retirer le membre'),
          content: Text(
            'Retirer "${member.resourceName}" du groupe "${group.name}" ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Retirer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _groupApi.removeMember(
        groupId: group.id,
        resourceId: member.resourceId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membre retiré du groupe.')),
      );

      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;

    String message = 'Erreur groupe ressource.';

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data?.toString() ?? '';

      if (responseData.contains('retire') ||
          responseData.contains('membres') ||
          responseData.contains('Impossible de supprimer ce groupe')) {
        message =
            'Impossible de supprimer ce groupe : retire d’abord ses membres.';
      } else if (statusCode == 400) {
        message =
            'Action invalide : vérifie le groupe, la ressource, ou un doublon existant.';
      } else if (statusCode == 404) {
        message = 'Groupe, membre ou ressource introuvable.';
      } else if (statusCode == 500) {
        message = 'Erreur serveur sur les groupes de ressources.';
      }
    } else {
      final raw = error.toString();

      if (raw.contains('retire') ||
          raw.contains('membres') ||
          raw.contains('Impossible de supprimer ce groupe')) {
        message =
            'Impossible de supprimer ce groupe : retirez d’abord ses membres.';
      } else if (raw.contains('400')) {
        message =
            'Action invalide : vérifiez le groupe, la ressource, ou un doublon existant.';
      } else if (raw.contains('404')) {
        message = 'Groupe, membre ou ressource introuvable.';
      } else if (raw.contains('500')) {
        message = 'Erreur serveur sur les groupes de ressources.';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResourceGroupsData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur groupes : ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return const Center(child: Text('Aucune donnée groupe.'));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Groupes de ressources',
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
                    onPressed: _createGroup,
                    icon: const Icon(Icons.add),
                    label: const Text('Nouveau groupe'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: data.groups.isEmpty
                  ? const Center(child: Text('Aucun groupe de ressources.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: data.groups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final group = data.groups[index];

                        return _ResourceGroupCard(
                          group: group,
                          resources: data.resources,
                          onEdit: () => _editGroup(group),
                          onDelete: () => _deleteGroup(group),
                          onAddMember: () =>
                              _addMemberToGroup(group, data.resources),
                          onRemoveMember: (member) =>
                              _removeMember(group, member),
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

class _ResourceGroupCard extends StatelessWidget {
  final ResourceGroup group;
  final List<Resource> resources;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddMember;
  final ValueChanged<ResourceGroupMember> onRemoveMember;

  const _ResourceGroupCard({
    required this.group,
    required this.resources,
    required this.onEdit,
    required this.onDelete,
    required this.onAddMember,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.group_work_outlined),
        title: Text(group.name),
        subtitle: Text(
          group.description?.isNotEmpty == true
              ? '${group.description} · ${group.members.length} membre(s)'
              : '${group.members.length} membre(s)',
        ),
        trailing: SizedBox(
          width: 146,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Ajouter membre',
                onPressed: onAddMember,
                icon: const Icon(Icons.person_add_alt),
              ),
              IconButton(
                tooltip: 'Modifier',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        children: [
          if (group.members.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Aucun membre dans ce groupe.'),
              ),
            )
          else
            ...group.members.map((member) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.person_outline),
                title: Text(member.resourceName),
                subtitle: Text(
                  'Type : ${member.resourceType} | '
                  'Capacité : ${member.capacityHoursPerWeek}h/semaine | '
                  'Coût : ${member.costPerHour}€/h',
                ),
                trailing: IconButton(
                  tooltip: 'Retirer du groupe',
                  onPressed: () => onRemoveMember(member),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ResourceGroupsData {
  final List<ResourceGroup> groups;
  final List<Resource> resources;

  _ResourceGroupsData({
    required this.groups,
    required this.resources,
  });
}