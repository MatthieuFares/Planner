import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../gantt/presentation/gantt_view.dart';
import '../../project_baseline/presentation/project_baseline_view.dart';
import '../../project_calendar/presentation/project_calendar_view.dart';
import '../../planning_versions/presentation/planning_versions_view.dart';
import '../../resources/presentation/resources_tab.dart';
import '../data/project_api.dart';
import '../data/project_insights_api.dart';
import '../data/project_model.dart';
import 'resource_analysis_card.dart';
import 'summary_card.dart';
import 'warnings_panel.dart';

enum _DashboardBlock {
  summary,
  alerts,
  resources,
}

enum _DashboardViewMode {
  management,
  compact,
}

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  final String? initialProjectName;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.initialProjectName,
  });

  @override
  State<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState
    extends State<ProjectDetailScreen> {
  final ProjectApi _projectApi = ProjectApi();
  final ProjectInsightsApi _insightsApi =
      ProjectInsightsApi();

  int _selectedTabIndex = 0;

  late Future<Project?> _projectFuture;
  late Future<_ProjectInsightsData> _insightsFuture;

  List<_DashboardBlock> _dashboardOrder =
      const <_DashboardBlock>[
    _DashboardBlock.summary,
    _DashboardBlock.alerts,
    _DashboardBlock.resources,
  ];

  Set<_DashboardBlock> _visibleDashboardBlocks =
      <_DashboardBlock>{
    _DashboardBlock.summary,
    _DashboardBlock.alerts,
    _DashboardBlock.resources,
  };

  _DashboardViewMode _dashboardViewMode =
      _DashboardViewMode.management;

  @override
  void initState() {
    super.initState();
    _loadProject();
    _loadInsights();
  }

  void _loadProject() {
    _projectFuture =
        _projectApi.getProjectById(widget.projectId);
  }

  void _loadInsights() {
    _insightsFuture = _fetchInsights();
  }

  Future<_ProjectInsightsData> _fetchInsights() async {
    final summary =
        await _insightsApi.getSummary(widget.projectId);

    final warnings =
        await _insightsApi.getWarnings(widget.projectId);

    final resourceAnalysis =
        await _insightsApi.getResourceAnalysis(
      widget.projectId,
    );

    return _ProjectInsightsData(
      summary: summary,
      warnings: warnings,
      resourceAnalysis: resourceAnalysis,
    );
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loadProject();
      _loadInsights();
    });
  }

  void _updateDashboardOrder(
    List<_DashboardBlock> order,
  ) {
    setState(() {
      _dashboardOrder =
          List<_DashboardBlock>.from(order);
    });
  }

  void _updateDashboardVisibility(
    Set<_DashboardBlock> visibleBlocks,
  ) {
    setState(() {
      _visibleDashboardBlocks =
          Set<_DashboardBlock>.from(visibleBlocks);
    });
  }

  void _updateDashboardViewMode(
    _DashboardViewMode mode,
  ) {
    setState(() {
      _dashboardViewMode = mode;
    });
  }

  void _resetDashboardLayout() {
    setState(() {
      _dashboardOrder = const <_DashboardBlock>[
        _DashboardBlock.summary,
        _DashboardBlock.alerts,
        _DashboardBlock.resources,
      ];

      _visibleDashboardBlocks = <_DashboardBlock>{
        _DashboardBlock.summary,
        _DashboardBlock.alerts,
        _DashboardBlock.resources,
      };

      _dashboardViewMode =
          _DashboardViewMode.management;
    });
  }

  void _navigateFromWarning(
    WarningsNavigationTarget target,
  ) {
    final tabIndex = switch (target) {
      WarningsNavigationTarget.tasks => 5,
      WarningsNavigationTarget.dependencies => 5,
      WarningsNavigationTarget.resources => 1,
      WarningsNavigationTarget.calendar => 2,
      WarningsNavigationTarget.gantt => 5,
    };

    setState(() {
      _selectedTabIndex = tabIndex;
    });
  }

  Widget _buildSelectedTab() {
    switch (_selectedTabIndex) {
      case 0:
        return _DashboardTab(
          insightsFuture: _insightsFuture,
          order: _dashboardOrder,
          visibleBlocks: _visibleDashboardBlocks,
          viewMode: _dashboardViewMode,
          onOrderChanged: _updateDashboardOrder,
          onVisibilityChanged:
              _updateDashboardVisibility,
          onViewModeChanged:
              _updateDashboardViewMode,
          onResetLayout: _resetDashboardLayout,
          onWarningNavigate: _navigateFromWarning,
        );

      case 1:
        return ResourcesTab(
          projectId: widget.projectId,
        );

      case 2:
        return ProjectCalendarView(
          projectId: widget.projectId,
        );

      case 3:
        return ProjectBaselineView(
          projectId: widget.projectId,
        );

      case 4:
        return PlanningVersionsView(
          projectId: widget.projectId,
        );

      case 5:
        return GanttView(
          projectId: widget.projectId,
        );

      default:
        return _DashboardTab(
          insightsFuture: _insightsFuture,
          order: _dashboardOrder,
          visibleBlocks: _visibleDashboardBlocks,
          viewMode: _dashboardViewMode,
          onOrderChanged: _updateDashboardOrder,
          onVisibilityChanged:
              _updateDashboardVisibility,
          onViewModeChanged:
              _updateDashboardViewMode,
          onResetLayout: _resetDashboardLayout,
          onWarningNavigate: _navigateFromWarning,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackTitle =
        widget.initialProjectName ??
            'Projet #${widget.projectId}';

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Project?>(
          future: _projectFuture,
          builder: (context, snapshot) {
            final project = snapshot.data;

            return Text(
              project?.name ?? fallbackTitle,
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          FutureBuilder<Project?>(
            future: _projectFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Erreur projet : ${snapshot.error}',
                    style:
                        const TextStyle(color: Colors.red),
                  ),
                );
              }

              final project = snapshot.data;

              if (project == null) {
                return _ProjectHeaderFallback(
                  projectId: widget.projectId,
                  title: fallbackTitle,
                );
              }

              return _ProjectHeader(project: project);
            },
          ),
          NavigationBar(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedTabIndex = index;

                if (index == 0) {
                  _loadProject();
                  _loadInsights();
                }
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                label: 'Ressources',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.calendar_month_outlined,
                ),
                selectedIcon:
                    Icon(Icons.calendar_month),
                label: 'Calendrier',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.camera_alt_outlined,
                ),
                selectedIcon:
                    Icon(Icons.camera_alt),
                label: 'Baselines',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'Versions',
              ),
              NavigationDestination(
                icon: Icon(Icons.timeline),
                label: 'Gantt',
              ),
            ]
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildSelectedTab(),
          ),
        ],
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  final Project project;

  const _ProjectHeader({
    required this.project,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final code =
        project.projectCode?.isNotEmpty == true
            ? project.projectCode!
            : 'Code non défini';

    final client =
        project.clientName?.isNotEmpty == true
            ? project.clientName!
            : 'Client non défini';

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment:
            WrapCrossAlignment.center,
        children: [
          _HeaderChip(
            icon: Icons.badge_outlined,
            label: 'ID projet',
            value: '#${project.id}',
          ),
          _HeaderChip(
            icon:
                Icons.confirmation_number_outlined,
            label: 'Code',
            value: code,
          ),
          _HeaderChip(
            icon: Icons.business_outlined,
            label: 'Client',
            value: client,
          ),
          _HeaderChip(
            icon:
                Icons.calendar_month_outlined,
            label: 'Début',
            value: _formatDate(project.startDate),
          ),
          _HeaderChip(
            icon:
                Icons.event_available_outlined,
            label: 'Fin',
            value: _formatDate(project.endDate),
          ),
        ],
      ),
    );
  }
}

class _ProjectHeaderFallback
    extends StatelessWidget {
  final int projectId;
  final String title;

  const _ProjectHeaderFallback({
    required this.projectId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _HeaderChip(
            icon: Icons.folder_open,
            label: 'Projet',
            value: title,
          ),
          _HeaderChip(
            icon: Icons.badge_outlined,
            label: 'ID projet',
            value: '#$projectId',
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label : $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _DashboardTab extends StatefulWidget {
  final Future<_ProjectInsightsData> insightsFuture;
  final List<_DashboardBlock> order;
  final Set<_DashboardBlock> visibleBlocks;
  final _DashboardViewMode viewMode;
  final ValueChanged<List<_DashboardBlock>>
      onOrderChanged;
  final ValueChanged<Set<_DashboardBlock>>
      onVisibilityChanged;
  final ValueChanged<_DashboardViewMode>
      onViewModeChanged;
  final VoidCallback onResetLayout;
  final ValueChanged<WarningsNavigationTarget>
      onWarningNavigate;

  const _DashboardTab({
    required this.insightsFuture,
    required this.order,
    required this.visibleBlocks,
    required this.viewMode,
    required this.onOrderChanged,
    required this.onVisibilityChanged,
    required this.onViewModeChanged,
    required this.onResetLayout,
    required this.onWarningNavigate,
  });

  @override
  State<_DashboardTab> createState() =>
      _DashboardTabState();
}

class _DashboardTabState
    extends State<_DashboardTab> {
  bool _isOrganizing = false;

  Future<void> _showLayoutDialog() async {
    var temporaryOrder =
        List<_DashboardBlock>.from(widget.order);

    var temporaryVisibility =
        Set<_DashboardBlock>.from(
      widget.visibleBlocks,
    );

    final result =
        await showDialog<_DashboardLayoutResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            dialogContext,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.dashboard_customize_outlined),
                  SizedBox(width: 10),
                  Text('Configurer le Dashboard'),
                ],
              ),
              content: SizedBox(
                width: 520,
                height: 390,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Choisis les blocs affichés et '
                      'déplace-les avec la poignée.',
                      style: Theme.of(dialogContext)
                          .textTheme
                          .bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: temporaryOrder.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setDialogState(() {
                            final item =
                                temporaryOrder.removeAt(
                              oldIndex,
                            );

                            temporaryOrder.insert(
                              newIndex,
                              item,
                            );
                          });
                        },
                        itemBuilder: (
                          context,
                          index,
                        ) {
                          final block =
                              temporaryOrder[index];

                          return Card(
                            key: ValueKey(block),
                            child: CheckboxListTile(
                              value:
                                  temporaryVisibility
                                      .contains(block),
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    temporaryVisibility
                                        .add(block);
                                  } else {
                                    temporaryVisibility
                                        .remove(block);
                                  }
                                });
                              },
                              secondary: ReorderableDragStartListener(
                                index: index,
                                child: const Icon(
                                  Icons.drag_handle,
                                ),
                              ),
                              title: Text(
                                _dashboardBlockLabel(
                                  block,
                                ),
                              ),
                              subtitle: Text(
                                _dashboardBlockDescription(
                                  block,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Annuler'),
                ),
                FilledButton.icon(
                  onPressed: temporaryVisibility.isEmpty
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(
                            _DashboardLayoutResult(
                              order: temporaryOrder,
                              visibleBlocks:
                                  temporaryVisibility,
                            ),
                          );
                        },
                  icon: const Icon(Icons.check),
                  label: const Text('Appliquer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;

    widget.onOrderChanged(result.order);
    widget.onVisibilityChanged(
      result.visibleBlocks,
    );
  }

  void _reorderDashboard(
    int oldIndex,
    int newIndex,
  ) {
    final visibleOrder = widget.order
        .where(widget.visibleBlocks.contains)
        .toList();

    final movedBlock =
        visibleOrder.removeAt(oldIndex);

    visibleOrder.insert(newIndex, movedBlock);

    final hiddenBlocks = widget.order
        .where(
          (block) =>
              !widget.visibleBlocks.contains(block),
        )
        .toList();

    widget.onOrderChanged(
      <_DashboardBlock>[
        ...visibleOrder,
        ...hiddenBlocks,
      ],
    );
  }

  Widget _buildDashboardBlock(
    _DashboardBlock block,
    _ProjectInsightsData data,
  ) {
    switch (block) {
      case _DashboardBlock.summary:
        return SummaryCard(
          summary: data.summary,
        );

      case _DashboardBlock.alerts:
        return WarningsPanel(
          warnings: data.warnings,
          onNavigate: widget.onWarningNavigate,
        );

      case _DashboardBlock.resources:
        return ResourceAnalysisCard(
          analysis: data.resourceAnalysis,
        );
    }
  }

  Widget _buildToolbar(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment:
          WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: () {
            setState(() {
              _isOrganizing = !_isOrganizing;
            });
          },
          icon: Icon(
            _isOrganizing
                ? Icons.check
                : Icons.open_with_outlined,
          ),
          label: Text(
            _isOrganizing
                ? 'Terminer le déplacement'
                : 'Déplacer les widgets',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _showLayoutDialog,
          icon: const Icon(
            Icons.dashboard_customize_outlined,
          ),
          label: const Text('Blocs affichés'),
        ),
        SizedBox(
          width: 190,
          child:
              DropdownButtonFormField<_DashboardViewMode>(
            initialValue: widget.viewMode,
            decoration: const InputDecoration(
              labelText: 'Mode d’affichage',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value:
                    _DashboardViewMode.management,
                child: Text('Management'),
              ),
              DropdownMenuItem(
                value: _DashboardViewMode.compact,
                child: Text('Compact'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;

              widget.onViewModeChanged(value);
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onResetLayout,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Réinitialiser'),
        ),
        Chip(
          avatar: const Icon(
            Icons.visibility_outlined,
            size: 17,
          ),
          label: Text(
            '${widget.visibleBlocks.length} bloc(s) affiché(s)',
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildManagementLayout(
    List<_DashboardBlock> visibleOrder,
    _ProjectInsightsData data,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        for (var index = 0;
            index < visibleOrder.length;
            index++) ...[
          _buildDashboardBlock(
            visibleOrder[index],
            data,
          ),
          if (index < visibleOrder.length - 1)
            const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    List<_DashboardBlock> visibleOrder,
    _ProjectInsightsData data,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canUseTwoColumns =
            constraints.maxWidth >= 1180;

        final halfWidth = canUseTwoColumns
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: visibleOrder.map((block) {
            final fullWidth =
                block == _DashboardBlock.summary ||
                    !canUseTwoColumns;

            return SizedBox(
              width: fullWidth
                  ? constraints.maxWidth
                  : halfWidth,
              child: _buildDashboardBlock(
                block,
                data,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildOrganizingLayout(
    List<_DashboardBlock> visibleOrder,
    _ProjectInsightsData data,
  ) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: visibleOrder.length,
      onReorderItem: _reorderDashboard,
      itemBuilder: (context, index) {
        final block = visibleOrder[index];

        return Padding(
          key: ValueKey(block),
          padding: const EdgeInsets.only(bottom: 16),
          child: _DashboardMovableShell(
            index: index,
            title: _dashboardBlockLabel(block),
            child: _buildDashboardBlock(
              block,
              data,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProjectInsightsData>(
      future: widget.insightsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur dashboard : ${snapshot.error}',
              style:
                  const TextStyle(color: Colors.red),
            ),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return const Center(
            child: Text(
              'Aucune donnée dashboard.',
            ),
          );
        }

        final visibleOrder = widget.order
            .where(widget.visibleBlocks.contains)
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 1600),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.dashboard_customize_outlined,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tableau de bord configurable',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildToolbar(context),
                  const SizedBox(height: 16),
                  if (visibleOrder.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucun bloc affiché. '
                          'Ouvre « Blocs affichés » '
                          'pour restaurer le Dashboard.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else if (_isOrganizing)
                    _buildOrganizingLayout(
                      visibleOrder,
                      data,
                    )
                  else if (widget.viewMode ==
                      _DashboardViewMode.compact)
                    _buildCompactLayout(
                      context,
                      visibleOrder,
                      data,
                    )
                  else
                    _buildManagementLayout(
                      visibleOrder,
                      data,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardMovableShell
    extends StatelessWidget {
  final int index;
  final String title;
  final Widget child;

  const _DashboardMovableShell({
    required this.index,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.30),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.35),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Text(
                  'Glisser pour déplacer',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _DashboardLayoutResult {
  final List<_DashboardBlock> order;
  final Set<_DashboardBlock> visibleBlocks;

  const _DashboardLayoutResult({
    required this.order,
    required this.visibleBlocks,
  });
}

String _dashboardBlockLabel(
  _DashboardBlock block,
) {
  switch (block) {
    case _DashboardBlock.summary:
      return 'Résumé et avancement';
    case _DashboardBlock.alerts:
      return 'Alertes graphiques';
    case _DashboardBlock.resources:
      return 'Analyse ressources';
  }
}

String _dashboardBlockDescription(
  _DashboardBlock block,
) {
  switch (block) {
    case _DashboardBlock.summary:
      return 'Progression, tâches, criticité, charge et coût.';
    case _DashboardBlock.alerts:
      return 'Retards, criticité, ressources et anomalies.';
    case _DashboardBlock.resources:
      return 'Capacité, charge, coûts et répartition.';
  }
}

class _ProjectInsightsData {
  final Map<String, dynamic> summary;
  final List<dynamic> warnings;
  final Map<String, dynamic> resourceAnalysis;

  _ProjectInsightsData({
    required this.summary,
    required this.warnings,
    required this.resourceAnalysis,
  });
}
