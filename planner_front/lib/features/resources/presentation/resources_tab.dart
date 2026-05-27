import 'package:flutter/material.dart';

import '../data/resource_api.dart';
import '../data/resource_model.dart';
import 'resource_form_dialog.dart';
import 'resource_assignment_tab.dart';
import 'resource_groups_tab.dart';

class ResourcesTab extends StatefulWidget {
  final int projectId;

  const ResourcesTab({
    super.key,
    required this.projectId,
  });

  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab> {
  final ResourceApi _resourceApi = ResourceApi();

  late Future<List<Resource>> _resourcesFuture;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  void _loadResources() {
    _resourcesFuture = _resourceApi.getResources();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadResources();
    });
  }

  Future<void> _createResource() async {
    final request = await showDialog<ResourceCreateRequest>(
      context: context,
      builder: (context) {
        return const ResourceFormDialog();
      },
    );

    if (request == null) return;

    try {
      await _resourceApi.createResource(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ressource créée avec succès.'),
        ),
      );

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatResourceError(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editResource(Resource resource) async {
    final request = await showDialog<ResourceUpdateRequest>(
      context: context,
      builder: (context) {
        return ResourceFormDialog(resource: resource);
      },
    );

    if (request == null) return;

    try {
      await _resourceApi.updateResource(resource.id, request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ressource modifiée avec succès.'),
        ),
      );

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatResourceError(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteResource(Resource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la ressource'),
          content: Text(
            'Voulez-vous vraiment supprimer "${resource.name}" ?\n\n'
            'Si elle est utilisée dans des assignations, le backend peut refuser la suppression.',
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
      await _resourceApi.deleteResource(resource.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ressource supprimée avec succès.'),
        ),
      );

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatResourceDeleteError(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatResourceError(Object error) {
    final raw = error.toString();

    if (raw.contains('400')) {
      return 'Requête invalide : vérifie les champs de la ressource.';
    }

    if (raw.contains('404')) {
      return 'Ressource introuvable.';
    }

    return 'Erreur ressource.';
  }

  String _formatResourceDeleteError(Object error) {
    final raw = error.toString();

    if (raw.contains('400') || raw.contains('500')) {
      return 'Impossible de supprimer cette ressource : elle est probablement liée à une assignation ou à un groupe.';
    }

    if (raw.contains('404')) {
      return 'Impossible de supprimer cette ressource : elle est introuvable.';
    }

    return 'Erreur lors de la suppression de la ressource.';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.assignment_ind_outlined),
                text: 'Assignations',
              ),
              Tab(
                icon: Icon(Icons.groups_outlined),
                text: 'Ressources',
              ),
              Tab(
                icon: Icon(Icons.group_work_outlined),
                text: 'Groupes',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ResourceAssignmentsTab(projectId: widget.projectId),
                _buildResourcesList(),
                const ResourceGroupsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourcesList() {
    return FutureBuilder<List<Resource>>(
      future: _resourcesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur ressources : ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final resources = snapshot.data ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Ressources',
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
                    onPressed: _createResource,
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle ressource'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: resources.isEmpty
                  ? const Center(
                      child: Text('Aucune ressource.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: resources.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final resource = resources[index];

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(resource.name),
                            subtitle: Text(
                              'Type : ${resource.type} | '
                              'Capacité : ${resource.capacityHoursPerWeek}h/semaine | '
                              'Coût : ${resource.costPerHour}€/h',
                            ),
                            trailing: SizedBox(
                              width: 104,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: 'Modifier',
                                    onPressed: () => _editResource(resource),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    onPressed: () => _deleteResource(resource),
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