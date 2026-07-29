import 'package:flutter/material.dart';

import '../../projects/data/project_access_api.dart';
import '../../projects/data/project_access_model.dart';
import '../data/resource_analysis_api.dart';
import '../data/resource_analysis_model.dart';
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
  final ProjectAccessApi _projectAccessApi =
      ProjectAccessApi();

  final ResourceApi _resourceApi = ResourceApi();
  final ResourceAnalysisApi _resourceAnalysisApi =
      ResourceAnalysisApi();

  late Future<ProjectAccessModel> _accessFuture;
  Future<_ResourcesData>? _resourcesFuture;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  void _loadAccess() {
    _resourcesFuture = null;

    _accessFuture = _projectAccessApi
        .getProjectAccess(widget.projectId)
        .then((access) {
      if (access.canReadResourceCatalog) {
        _resourcesFuture = _fetchResourcesData();
      }

      return access;
    });
  }

  void _loadResources() {
    _resourcesFuture = _fetchResourcesData();
  }

  Future<_ResourcesData> _fetchResourcesData() async {
    final resources = await _resourceApi.getResources();

    final analysis = await _resourceAnalysisApi.getProjectAnalysis(
      widget.projectId,
    );

    return _ResourcesData(
      resources: resources,
      analysis: analysis,
    );
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

  String _formatHours(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatPercent(double? value) {
    if (value == null) return '-';

    if (value == value.roundToDouble()) {
      return '${value.toInt()}%';
    }

    return '${value.toStringAsFixed(1)}%';
  }

  List<_ResourceFinancialRow> _buildFinancialRows(_ResourcesData data) {
    final statsByResourceId = {
      for (final stat in data.analysis.resources) stat.resourceId: stat,
    };

    final rows = data.resources.map((resource) {
      final stat = statsByResourceId[resource.id];

      final assignedHours = stat?.assignedHours ?? 0;
      final capacityHours = resource.capacityHoursPerWeek;
      final costPerHour = resource.costPerHour;
      final estimatedCost = assignedHours * costPerHour;

      double? utilizationPercent;

      if (capacityHours > 0) {
        utilizationPercent = assignedHours / capacityHours * 100;
      }

      final isOverloaded =
          utilizationPercent != null && utilizationPercent > 100;

      return _ResourceFinancialRow(
        resource: resource,
        assignedHours: assignedHours,
        capacityHoursPerWeek: capacityHours,
        costPerHour: costPerHour,
        estimatedCost: estimatedCost,
        utilizationPercent: utilizationPercent,
        isOverloaded: isOverloaded,
      );
    }).toList();

    rows.sort((a, b) {
      final byHours = b.assignedHours.compareTo(a.assignedHours);

      if (byHours != 0) return byHours;

      return a.resource.name.compareTo(b.resource.name);
    });

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProjectAccessModel>(
      future: _accessFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return _ProjectAccessErrorState(
            error: snapshot.error,
            onRetry: () {
              setState(() {
                _loadAccess();
              });
            },
          );
        }

        final access = snapshot.data;

        if (access == null ||
            !access.canReadProject) {
          return const Center(
            child: Text(
              'Accès au projet indisponible.',
            ),
          );
        }

        final tabs = <Tab>[
          const Tab(
            icon: Icon(
              Icons.assignment_ind_outlined,
            ),
            text: 'Assignations',
          ),
        ];

        final views = <Widget>[
          ResourceAssignmentsTab(
            projectId: widget.projectId,
          ),
        ];

        if (access.canReadResourceCatalog) {
          tabs.addAll(
            const [
              Tab(
                icon: Icon(Icons.groups_outlined),
                text: 'Ressources',
              ),
              Tab(
                icon: Icon(
                  Icons.group_work_outlined,
                ),
                text: 'Groupes',
              ),
            ],
          );

          views.addAll(
            [
              _buildResourcesList(access),
              const ResourceGroupsTab(),
            ],
          );
        }

        return DefaultTabController(
          length: tabs.length,
          child: Column(
            children: [
              TabBar(tabs: tabs),
              Expanded(
                child: TabBarView(
                  children: views,
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildResourcesList(
    ProjectAccessModel access,
  ) {
    final resourcesFuture = _resourcesFuture;

    if (resourcesFuture == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return FutureBuilder<_ResourcesData>(
      future: resourcesFuture,
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

        final data = snapshot.data;

        if (data == null) {
          return const Center(
            child: Text('Aucune donnée ressources.'),
          );
        }

        final resources = data.resources;
        final financialRows = _buildFinancialRows(data);

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
                  if (access.canManageResourceCatalog) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _createResource,
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Nouvelle ressource',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _ResourceFinancialSummary(
                    resourceCount: resources.length,
                    totalWorkloadHours: data.analysis.totalWorkloadHours,
                    estimatedCost: data.analysis.estimatedCost,
                    overloadedResourceCount: financialRows
                        .where((row) => row.isOverloaded)
                        .length,
                    formatHours: _formatHours,
                    formatMoney: _formatMoney,
                  ),
                  const SizedBox(height: 12),
                  _ResourceFinancialTable(
                    rows: financialRows,
                    formatHours: _formatHours,
                    formatMoney: _formatMoney,
                    formatPercent: _formatPercent,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Liste des ressources',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (resources.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('Aucune ressource.'),
                      ),
                    )
                  else
                    ...resources.map((resource) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                              resource.type.toLowerCase() == 'team'
                                  ? Icons.groups_outlined
                                  : Icons.person_outline,
                            ),
                            title: Text(resource.name),
                            subtitle: Text(
                              'Type : ${resource.type} | '
                              'Capacité : ${resource.capacityHoursPerWeek}h/semaine | '
                              'Coût : ${_formatMoney(resource.costPerHour)}€/h',
                            ),
                            trailing:
                                access.canManageResourceCatalog
                                    ? SizedBox(
                                        width: 104,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              tooltip: 'Modifier',
                                              onPressed: () =>
                                                  _editResource(
                                                resource,
                                              ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Supprimer',
                                              onPressed: () =>
                                                  _deleteResource(
                                                resource,
                                              ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const Tooltip(
                                        message:
                                            'Catalogue en lecture seule',
                                        child: Icon(
                                          Icons.visibility_outlined,
                                        ),
                                      ),
                          ),
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

class _ProjectAccessErrorState
    extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ProjectAccessErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 42,
                color: Theme.of(context)
                    .colorScheme
                    .error,
              ),
              const SizedBox(height: 10),
              const Text(
                'Impossible de déterminer vos droits '
                'sur ce projet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                error?.toString() ??
                    'Erreur inconnue',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceFinancialSummary extends StatelessWidget {
  final int resourceCount;
  final double totalWorkloadHours;
  final double estimatedCost;
  final int overloadedResourceCount;

  final String Function(double value) formatHours;
  final String Function(double value) formatMoney;

  const _ResourceFinancialSummary({
    required this.resourceCount,
    required this.totalWorkloadHours,
    required this.estimatedCost,
    required this.overloadedResourceCount,
    required this.formatHours,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyse financière des ressources',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ResourceMetricTile(
                  icon: Icons.groups_outlined,
                  label: 'Ressources',
                  value: '$resourceCount',
                ),
                _ResourceMetricTile(
                  icon: Icons.access_time,
                  label: 'Charge totale',
                  value: '${formatHours(totalWorkloadHours)} h',
                ),
                _ResourceMetricTile(
                  icon: Icons.euro,
                  label: 'Coût total',
                  value: '${formatMoney(estimatedCost)} €',
                ),
                _ResourceMetricTile(
                  icon: Icons.warning_amber_outlined,
                  label: 'Surchargées',
                  value: '$overloadedResourceCount',
                  isWarning: overloadedResourceCount > 0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isWarning;

  const _ResourceMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? Colors.red : Theme.of(context).colorScheme.primary;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWarning
              ? Colors.red.withValues(alpha: 0.35)
              : Theme.of(context).dividerColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isWarning ? Colors.red : null,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _ResourceFinancialTable extends StatelessWidget {
  final List<_ResourceFinancialRow> rows;

  final String Function(double value) formatHours;
  final String Function(double value) formatMoney;
  final String Function(double? value) formatPercent;

  const _ResourceFinancialTable({
    required this.rows,
    required this.formatHours,
    required this.formatMoney,
    required this.formatPercent,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucune ressource à analyser.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Ressource')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Charge')),
              DataColumn(label: Text('Capacité')),
              DataColumn(label: Text('Utilisation')),
              DataColumn(label: Text('Taux')),
              DataColumn(label: Text('Coût total')),
              DataColumn(label: Text('Statut')),
            ],
            rows: rows.map((row) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      row.resource.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(Text(row.resource.type)),
                  DataCell(Text('${formatHours(row.assignedHours)} h')),
                  DataCell(Text('${row.capacityHoursPerWeek} h')),
                  DataCell(Text(formatPercent(row.utilizationPercent))),
                  DataCell(Text('${formatMoney(row.costPerHour)} €/h')),
                  DataCell(Text('${formatMoney(row.estimatedCost)} €')),
                  DataCell(
                    Chip(
                      label: Text(
                        row.isOverloaded ? 'Surchargée' : 'OK',
                      ),
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        row.isOverloaded
                            ? Icons.warning_amber_outlined
                            : Icons.check_circle_outline,
                        size: 16,
                        color: row.isOverloaded
                            ? Colors.red
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ResourcesData {
  final List<Resource> resources;
  final ProjectResourceAnalysis analysis;

  const _ResourcesData({
    required this.resources,
    required this.analysis,
  });
}

class _ResourceFinancialRow {
  final Resource resource;

  final double assignedHours;
  final int capacityHoursPerWeek;
  final double costPerHour;
  final double estimatedCost;
  final double? utilizationPercent;
  final bool isOverloaded;

  const _ResourceFinancialRow({
    required this.resource,
    required this.assignedHours,
    required this.capacityHoursPerWeek,
    required this.costPerHour,
    required this.estimatedCost,
    required this.utilizationPercent,
    required this.isOverloaded,
  });
}