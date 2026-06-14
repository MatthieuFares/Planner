import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/project_api.dart';
import '../data/project_model.dart';
import 'project_detail_screen.dart';
import 'project_form_dialog.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final ProjectApi _projectApi = ProjectApi();

  late Future<List<Project>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  void _loadProjects() {
    _projectsFuture = _projectApi.getProjects();
  }

  Future<void> _refreshProjects() async {
    setState(() {
      _loadProjects();
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _projectSubtitle(Project project) {
    final client = project.clientName?.isNotEmpty == true
        ? project.clientName!
        : 'Client non défini';

    final code = project.projectCode?.isNotEmpty == true
        ? project.projectCode!
        : 'Code non défini';

    final dates =
        'Début : ${_formatDate(project.startDate)} | Fin : ${_formatDate(project.endDate)}';

    final description = project.description?.isNotEmpty == true
        ? project.description!
        : 'Aucune description';

    return '$code · $client\n$dates\n$description';
  }

  void _openProject(Project project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(
          projectId: project.id,
          initialProjectName: project.name,
        ),
      ),
    );
  }

  Future<void> _createProject() async {
    final request = await showDialog<ProjectCreateRequest>(
      context: context,
      builder: (context) {
        return const ProjectFormDialog();
      },
    );

    if (request == null) return;

    try {
      await _projectApi.createProject(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Projet créé avec succès.'),
        ),
      );

      await _refreshProjects();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editProject(Project project) async {
    final request = await showDialog<ProjectUpdateRequest>(
      context: context,
      builder: (context) {
        return ProjectFormDialog(project: project);
      },
    );

    if (request == null) return;

    try {
      await _projectApi.updateProject(project.id, request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Projet modifié avec succès.'),
        ),
      );

      await _refreshProjects();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la modification : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le projet'),
          content: Text(
            'Voulez-vous vraiment supprimer "${project.name}" ?\n\n'
            'Attention : les tâches liées peuvent aussi être supprimées.',
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
      await _projectApi.deleteProject(project.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Projet supprimé avec succès.'),
        ),
      );

      await _refreshProjects();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildProjectCard(Project project) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.folder_open),
        title: Row(
          children: [
            Expanded(
              child: Text(
                project.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text('Projet #${project.id}'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_projectSubtitle(project)),
        ),
        isThreeLine: true,
        onTap: () => _openProject(project),
        trailing: SizedBox(
          width: 104,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Modifier',
                onPressed: () => _editProject(project),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: () => _deleteProject(project),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes projets'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _refreshProjects,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau projet'),
      ),
      body: FutureBuilder<List<Project>>(
        future: _projectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erreur lors du chargement des projets : ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final projects = snapshot.data ?? [];

          if (projects.isEmpty) {
            return const Center(
              child: Text('Aucun projet trouvé.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildProjectCard(projects[index]);
            },
          );
        },
      ),
    );
  }
}