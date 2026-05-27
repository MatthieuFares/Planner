import 'package:flutter/material.dart';

import '../../dependencies/presentation/dependency_tab.dart';
import '../../gantt/presentation/gantt_view.dart';
import '../../tasks/presentation/task_list.dart';
import '../data/project_insights_api.dart';
import 'resource_analysis_card.dart';
import 'summary_card.dart';
import 'warnings_panel.dart';
import '../../resources/presentation/resources_tab.dart';

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
  final ProjectInsightsApi _insightsApi = ProjectInsightsApi();

  int _selectedTabIndex = 0;

  late Future<_ProjectInsightsData> _insightsFuture;

  @override
  void initState() {
    super.initState();
    _loadInsights();
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

  Future<void> _refreshInsights() async {
    setState(() {
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
        return GanttView(projectId: widget.projectId);

      default:
        return _DashboardTab(
          insightsFuture: _insightsFuture,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initialProjectName ?? 'Projet #${widget.projectId}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_selectedTabIndex == 1)
            IconButton(
              tooltip: 'Rafraîchir le dashboard',
              onPressed: _refreshInsights,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Column(
        children: [
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