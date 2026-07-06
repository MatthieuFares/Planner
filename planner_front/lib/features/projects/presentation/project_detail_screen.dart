import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../dependencies/presentation/dependency_tab.dart';
import '../../gantt/presentation/gantt_view.dart';
import '../../tasks/presentation/task_list.dart';
import '../data/project_api.dart';
import '../data/project_insights_api.dart';
import '../data/project_model.dart';
import 'resource_analysis_card.dart';
import 'summary_card.dart';
import 'warnings_panel.dart';
import '../../resources/presentation/resources_tab.dart';
import '../../project_calendar/presentation/project_calendar_view.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  final String? initialProjectName;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.initialProjectName,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ProjectApi _projectApi = ProjectApi();
  final ProjectInsightsApi _insightsApi = ProjectInsightsApi();

  int _selectedTabIndex = 0;

  late Future<Project?> _projectFuture;
  late Future<_ProjectInsightsData> _insightsFuture;

  @override
  void initState() {
    super.initState();
    _loadProject();
    _loadInsights();
  }

  void _loadProject() {
    _projectFuture = _projectApi.getProjectById(widget.projectId);
  }

  void _loadInsights() {
    _insightsFuture = _fetchInsights();
  }

  Future<_ProjectInsightsData> _fetchInsights() async {
    final summary = await _insightsApi.getSummary(widget.projectId);
    final warnings = await _insightsApi.getWarnings(widget.projectId);
    final resourceAnalysis =
        await _insightsApi.getResourceAnalysis(widget.projectId);

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

  Widget _buildSelectedTab() {
    switch (_selectedTabIndex) {
      case 0:
        return _DashboardTab(
          insightsFuture: _insightsFuture,
        );

      case 1:
        return TaskList(projectId: widget.projectId);

      case 2:
        return DependenciesTab(projectId: widget.projectId);

      case 3:
        return ResourcesTab(projectId: widget.projectId);
            
      case 4:
        return ProjectCalendarView(projectId: widget.projectId);

      case 5:
        return GanttView(projectId: widget.projectId);

      default:
        return _DashboardTab(
          insightsFuture: _insightsFuture,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackTitle =
        widget.initialProjectName ?? 'Projet #${widget.projectId}';

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Project?>(
          future: _projectFuture,
          builder: (context, snapshot) {
            final project = snapshot.data;

            return Text(project?.name ?? fallbackTitle);
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Erreur projet : ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
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
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist),
                label: 'Tâches',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_tree_outlined),
                label: 'Dépendances',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                label: 'Ressources',
              ),
              const NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Calendrier',
              ),
              NavigationDestination(
                icon: Icon(Icons.timeline),
                label: 'Gantt',
              ),
            ],
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
    final code = project.projectCode?.isNotEmpty == true
        ? project.projectCode!
        : 'Code non défini';

    final client = project.clientName?.isNotEmpty == true
        ? project.clientName!
        : 'Client non défini';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _HeaderChip(
            icon: Icons.badge_outlined,
            label: 'ID projet',
            value: '#${project.id}',
          ),
          _HeaderChip(
            icon: Icons.confirmation_number_outlined,
            label: 'Code',
            value: code,
          ),
          _HeaderChip(
            icon: Icons.business_outlined,
            label: 'Client',
            value: client,
          ),
          _HeaderChip(
            icon: Icons.calendar_month_outlined,
            label: 'Début',
            value: _formatDate(project.startDate),
          ),
          _HeaderChip(
            icon: Icons.event_available_outlined,
            label: 'Fin',
            value: _formatDate(project.endDate),
          ),
        ],
      ),
    );
  }
}

class _ProjectHeaderFallback extends StatelessWidget {
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

class _DashboardTab extends StatelessWidget {
  final Future<_ProjectInsightsData> insightsFuture;

  const _DashboardTab({
    required this.insightsFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProjectInsightsData>(
      future: insightsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur dashboard : ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return const Center(
            child: Text('Aucune donnée dashboard.'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SummaryCard(summary: data.summary),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: WarningsPanel(warnings: data.warnings),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: ResourceAnalysisCard(
                      analysis: data.resourceAnalysis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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