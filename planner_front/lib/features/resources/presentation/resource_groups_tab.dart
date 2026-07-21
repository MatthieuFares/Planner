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

    final hydratedGroups = await Future.wait(
      groups.map((group) async {
        final members = await _groupApi.getMembers(group.id);

        return ResourceGroup(
          id: group.id,
          name: group.name,
          description: group.description,
          members: members,
        );
      }),
    );

    hydratedGroups.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    resources.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return _ResourceGroupsData(
      groups: hydratedGroups,
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
    final existingResourceIds = group.members
        .map((member) => member.resourceId)
        .toSet();

    final availableResources = resources
        .where(
          (resource) => !existingResourceIds.contains(resource.id),
        )
        .toList();

    if (availableResources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Toutes les ressources disponibles sont déjà membres '
            'de ce groupe.',
          ),
        ),
      );
      return;
    }

    final request = await showDialog<ResourceGroupMemberRequest>(
      context: context,
      builder: (_) => ResourceGroupMemberDialog(
        groups: [group],
        resources: availableResources,
      ),
    );

    if (!mounted || request == null) return;

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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  _ResourceGroupsSummary(
                    groups: data.groups,
                  ),
                  const SizedBox(height: 14),
                  if (data.groups.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(
                          child: Text('Aucun groupe de ressources.'),
                        ),
                      ),
                    )
                  else
                    ...data.groups.map((group) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ResourceGroupCard(
                          group: group,
                          resources: data.resources,
                          onEdit: () => _editGroup(group),
                          onDelete: () => _deleteGroup(group),
                          onAddMember: () =>
                              _addMemberToGroup(group, data.resources),
                          onRemoveMember: (member) =>
                              _removeMember(group, member),
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
    final stats = _ResourceGroupStats.fromGroup(group);
    final memberIds = group.members
        .map((member) => member.resourceId)
        .toSet();
    final availableResourceCount = resources
        .where((resource) => !memberIds.contains(resource.id))
        .length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: CircleAvatar(
          child: Text(
            '${group.members.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _GroupCompactChip(
                icon: Icons.people_outline,
                text: '${group.members.length} membre(s)',
              ),
              _GroupCompactChip(
                icon: Icons.access_time_outlined,
                text: '${_formatNumber(stats.totalCapacity)} h/sem.',
              ),
              _GroupCompactChip(
                icon: Icons.euro_outlined,
                text: '${_formatNumber(stats.totalHourlyCost)} €/h',
              ),
              if (group.description?.isNotEmpty == true)
                _GroupCompactChip(
                  icon: Icons.notes_outlined,
                  text: group.description!,
                ),
            ],
          ),
        ),
        trailing: SizedBox(
          width: 146,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: availableResourceCount == 0
                    ? 'Aucune ressource disponible à ajouter'
                    : 'Ajouter un membre',
                onPressed:
                    availableResourceCount == 0 ? null : onAddMember,
                icon: const Icon(Icons.person_add_alt),
              ),
              IconButton(
                tooltip: 'Modifier',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: group.members.isNotEmpty
                    ? 'Retire les membres avant de supprimer le groupe'
                    : 'Supprimer',
                onPressed: group.members.isNotEmpty ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        children: [
          const Divider(),
          _ResourceGroupStatsPanel(stats: stats),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Membres du groupe',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 8),
          if (group.members.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context)
                      .dividerColor
                      .withValues(alpha: 0.45),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Aucun membre dans ce groupe.'),
                  if (availableResourceCount > 0) ...[
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: onAddMember,
                      icon: const Icon(Icons.person_add_alt),
                      label: Text(
                        'Ajouter une ressource '
                        '($availableResourceCount disponible(s))',
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            ...group.members.map((member) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: ListTile(
                  dense: true,
                  tileColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  leading: Icon(_resourceTypeIcon(member.resourceType)),
                  title: Text(
                    member.resourceName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${_resourceTypeLabel(member.resourceType)} · '
                    '${_formatNumber(member.capacityHoursPerWeek)} h/sem. · '
                    '${_formatNumber(member.costPerHour)} €/h',
                  ),
                  trailing: IconButton(
                    tooltip: 'Retirer du groupe',
                    onPressed: () => onRemoveMember(member),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ResourceGroupsSummary extends StatelessWidget {
  final List<ResourceGroup> groups;

  const _ResourceGroupsSummary({required this.groups});

  @override
  Widget build(BuildContext context) {
    final memberships = groups.expand((group) => group.members).toList();
    final uniqueResources = memberships
        .map((member) => member.resourceId)
        .toSet()
        .length;
    final totalCapacity = memberships.fold<double>(
      0,
      (sum, member) => sum + member.capacityHoursPerWeek,
    );
    final totalHourlyCost = memberships.fold<double>(
      0,
      (sum, member) => sum + member.costPerHour,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _GroupMetric(
              icon: Icons.group_work_outlined,
              label: 'Groupes',
              value: '${groups.length}',
            ),
            _GroupMetric(
              icon: Icons.people_outline,
              label: 'Membres cumulés',
              value: '${memberships.length}',
              tooltip: 'Une même ressource peut appartenir à plusieurs groupes.',
            ),
            _GroupMetric(
              icon: Icons.person_outline,
              label: 'Ressources uniques',
              value: '$uniqueResources',
            ),
            _GroupMetric(
              icon: Icons.access_time_outlined,
              label: 'Capacité cumulée',
              value: '${_formatNumber(totalCapacity)} h/sem.',
            ),
            _GroupMetric(
              icon: Icons.euro_outlined,
              label: 'Coût horaire cumulé',
              value: '${_formatNumber(totalHourlyCost)} €/h',
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceGroupStatsPanel extends StatelessWidget {
  final _ResourceGroupStats stats;

  const _ResourceGroupStatsPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        children: [
          _GroupSmallStat(
            icon: Icons.people_outline,
            label: 'Membres',
            value: '${stats.memberCount}',
          ),
          _GroupSmallStat(
            icon: Icons.access_time_outlined,
            label: 'Capacité totale',
            value: '${_formatNumber(stats.totalCapacity)} h/sem.',
          ),
          _GroupSmallStat(
            icon: Icons.euro_outlined,
            label: 'Coût cumulé',
            value: '${_formatNumber(stats.totalHourlyCost)} €/h',
          ),
          _GroupSmallStat(
            icon: Icons.functions_outlined,
            label: 'Coût moyen',
            value: '${_formatNumber(stats.averageHourlyCost)} €/h',
          ),
        ],
      ),
    );
  }
}

class _GroupMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? tooltip;

  const _GroupMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: 205,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return tooltip == null
        ? content
        : Tooltip(message: tooltip!, child: content);
  }
}

class _GroupSmallStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _GroupSmallStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCompactChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GroupCompactChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceGroupStats {
  final int memberCount;
  final double totalCapacity;
  final double totalHourlyCost;
  final double averageHourlyCost;

  const _ResourceGroupStats({
    required this.memberCount,
    required this.totalCapacity,
    required this.totalHourlyCost,
    required this.averageHourlyCost,
  });

  factory _ResourceGroupStats.fromGroup(ResourceGroup group) {
    final count = group.members.length;
    final capacity = group.members.fold<double>(
      0,
      (sum, member) => sum + member.capacityHoursPerWeek,
    );
    final cost = group.members.fold<double>(
      0,
      (sum, member) => sum + member.costPerHour,
    );

    return _ResourceGroupStats(
      memberCount: count,
      totalCapacity: capacity,
      totalHourlyCost: cost,
      averageHourlyCost: count == 0 ? 0 : cost / count,
    );
  }
}

IconData _resourceTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'team':
      return Icons.groups_outlined;
    case 'material':
      return Icons.build_outlined;
    default:
      return Icons.person_outline;
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

String _formatNumber(num value) {
  final number = value.toDouble();

  if (number == number.roundToDouble()) {
    return number.toInt().toString();
  }

  return number.toStringAsFixed(1);
}

class _ResourceGroupsData {
  final List<ResourceGroup> groups;
  final List<Resource> resources;

  _ResourceGroupsData({
    required this.groups,
    required this.resources,
  });
}