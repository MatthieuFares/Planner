import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth/data/auth_session.dart';
import '../data/project_api.dart';
import '../data/project_interop_api.dart';
import '../data/project_model.dart';
import 'project_detail_screen.dart';
import 'project_form_dialog.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() =>
      _ProjectsPageState();
}

class _ProjectsPageState
    extends State<ProjectsPage> {
  final ProjectApi _projectApi = ProjectApi();
  final ProjectInteropApi _interopApi =
      ProjectInteropApi();

  late Future<ProjectListResult>
      _projectListFuture;

  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  void _loadProjects() {
    _projectListFuture =
        _projectApi.getProjectList();
  }

  Future<void> _refreshProjects() async {
    setState(_loadProjects);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _projectSubtitle(Project project) {
    final client =
        project.clientName?.isNotEmpty == true
            ? project.clientName!
            : 'Client non défini';

    final code =
        project.projectCode?.isNotEmpty == true
            ? project.projectCode!
            : 'Code non défini';

    final dates =
        'Début : ${_formatDate(project.startDate)} | '
        'Fin : ${_formatDate(project.endDate)}';

    final description =
        project.description?.isNotEmpty == true
            ? project.description!
            : 'Aucune description';

    return '$code · $client\n$dates\n$description';
  }

  void _openProject(Project project) {
    _openProjectById(
      projectId: project.id,
      projectName: project.name,
    );
  }

  void _openProjectById({
    required int projectId,
    required String projectName,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(
          projectId: projectId,
          initialProjectName: projectName,
        ),
      ),
    );
  }

  Future<void> _createProject() async {
    final request =
        await showDialog<ProjectCreateRequest>(
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
          content: Text(
            'Projet créé avec succès.',
          ),
        ),
      );

      await _refreshProjects();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la création : $error',
          ),
          backgroundColor:
              Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _importProject() async {
    if (_isImporting) return;

    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>[
        'xml',
        'mspdi',
      ],
      allowMultiple: false,
      withData: true,
    );

    if (selection == null ||
        selection.files.isEmpty) {
      return;
    }

    final selectedFile =
        selection.files.single;
    final bytes = selectedFile.bytes;

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Impossible de lire le fichier sélectionné.',
          ),
          backgroundColor:
              Theme.of(context).colorScheme.error,
        ),
      );

      return;
    }

    final importFile = ProjectImportFile(
      name: selectedFile.name,
      bytes: bytes,
    );

    setState(() {
      _isImporting = true;
    });

    try {
      final preview =
          await _interopApi.previewImport(
        importFile,
      );

      if (!mounted) return;

      final confirmed =
          await _showImportPreviewDialog(
        preview: preview,
        fileName: selectedFile.name,
      );

      if (confirmed != true) return;

      final result =
          await _interopApi.importProject(
        importFile,
      );

      if (!mounted) return;

      await _refreshProjects();

      if (!mounted) return;

      final warningSuffix =
          result.warnings.isEmpty
              ? ''
              : ' · ${result.warnings.length} '
                  'avertissement(s)';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Projet "${result.projectName}" '
            'importé avec succès'
            '$warningSuffix.',
          ),
        ),
      );

      _openProjectById(
        projectId: result.projectId,
        projectName: result.projectName,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l’import : $error',
          ),
          backgroundColor:
              Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<bool?> _showImportPreviewDialog({
    required ProjectImportPreview preview,
    required String fileName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.upload_file_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aperçu de l’import',
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Text(
                    preview.projectName,
                    style: Theme.of(dialogContext)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName,
                    style: Theme.of(dialogContext)
                        .textTheme
                        .bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ImportPreviewChip(
                        icon:
                            Icons.account_tree_outlined,
                        label:
                            '${preview.structureItemCount} '
                            'structure(s)',
                      ),
                      _ImportPreviewChip(
                        icon:
                            Icons.task_alt_outlined,
                        label:
                            '${preview.taskCount} '
                            'tâche(s)',
                      ),
                      _ImportPreviewChip(
                        icon: Icons.link,
                        label:
                            '${preview.dependencyCount} '
                            'dépendance(s)',
                      ),
                      _ImportPreviewChip(
                        icon:
                            Icons.people_outline,
                        label:
                            '${preview.resourceCount} '
                            'ressource(s)',
                      ),
                      _ImportPreviewChip(
                        icon: Icons
                            .assignment_ind_outlined,
                        label:
                            '${preview.assignmentCount} '
                            'assignation(s)',
                      ),
                      _ImportPreviewChip(
                        icon: Icons
                            .calendar_month_outlined,
                        label: preview.hasCalendar
                            ? 'Calendrier inclus'
                            : 'Pas de calendrier',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ImportPreviewDates(
                    preview: preview,
                  ),
                  if (preview.description
                          ?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 12),
                    Text(preview.description!),
                  ],
                  if (preview.warnings
                      .isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      preview.errorCount > 0
                          ? 'Erreurs et '
                              'avertissements'
                          : 'Avertissements',
                      style: Theme.of(
                        dialogContext,
                      )
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...preview.warnings.map(
                      (warning) =>
                          _ImportWarningTile(
                        warning: warning,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: preview.canImport
                          ? Theme.of(
                              dialogContext,
                            )
                              .colorScheme
                              .primaryContainer
                              .withValues(
                                alpha: 0.35,
                              )
                          : Theme.of(
                              dialogContext,
                            )
                              .colorScheme
                              .errorContainer,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Text(
                      preview.canImport
                          ? 'Le fichier peut être '
                              'importé. Un nouveau '
                              'projet Planner sera créé.'
                          : 'L’import est bloqué. '
                              'Corrigez les erreurs du '
                              'fichier avant de continuer.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: preview.canImport
                  ? () {
                      Navigator.of(
                        dialogContext,
                      ).pop(true);
                    }
                  : null,
              icon: const Icon(
                Icons.download_outlined,
              ),
              label: const Text('Importer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editProject(
    Project project,
  ) async {
    if (!project.canEditPlanning) return;

    final request =
        await showDialog<ProjectUpdateRequest>(
      context: context,
      builder: (context) {
        return ProjectFormDialog(
          project: project,
        );
      },
    );

    if (request == null) return;

    try {
      await _projectApi.updateProject(
        project.id,
        request,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Projet modifié avec succès.',
          ),
        ),
      );

      await _refreshProjects();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la modification : '
            '$error',
          ),
          backgroundColor:
              Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _deleteProject(
    Project project,
  ) async {
    if (!project.canDeleteProject) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Supprimer le projet',
          ),
          content: Text(
            'Voulez-vous vraiment supprimer '
            '"${project.name}" ?\n\n'
            'Cette action supprime définitivement '
            'le planning et ses données liées.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              icon: const Icon(
                Icons.delete_outline,
              ),
              label: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _projectApi.deleteProject(
        project.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Projet supprimé avec succès.',
          ),
        ),
      );

      await _refreshProjects();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la suppression : '
            '$error',
          ),
          backgroundColor:
              Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildProjectCard(Project project) {
    final canShowActions =
        project.canEditPlanning ||
            project.canDeleteProject;

    final actionCount =
        (project.canEditPlanning ? 1 : 0) +
            (project.canDeleteProject ? 1 : 0);

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
            if (!project.canEditPlanning)
              const Chip(
                avatar: Icon(
                  Icons.visibility_outlined,
                  size: 16,
                ),
                label: Text('Lecture seule'),
                visualDensity:
                    VisualDensity.compact,
              ),
            const SizedBox(width: 8),
            Chip(
              label:
                  Text('Projet #${project.id}'),
              visualDensity:
                  VisualDensity.compact,
            ),
          ],
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(top: 6),
          child: Text(
            _projectSubtitle(project),
          ),
        ),
        isThreeLine: true,
        onTap: () => _openProject(project),
        trailing: canShowActions
            ? SizedBox(
                width: actionCount * 52,
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    if (project
                        .canEditPlanning)
                      IconButton(
                        tooltip:
                            'Modifier le projet',
                        onPressed: () =>
                            _editProject(project),
                        icon: const Icon(
                          Icons.edit_outlined,
                        ),
                      ),
                    if (project
                        .canDeleteProject)
                      IconButton(
                        tooltip:
                            'Supprimer le projet',
                        onPressed: () =>
                            _deleteProject(project),
                        icon: const Icon(
                          Icons.delete_outline,
                        ),
                      ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Se déconnecter',
          ),
          content: const Text(
            'Voulez-vous fermer votre '
            'session Planner ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              icon: const Icon(Icons.logout),
              label: const Text(
                'Se déconnecter',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await AuthSession.instance.logout();
  }

  Widget _buildImportAction() {
    return FutureBuilder<ProjectListResult>(
      future: _projectListFuture,
      builder: (context, snapshot) {
        if (snapshot.data?.canImportProjects !=
            true) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
          ),
          child: OutlinedButton.icon(
            onPressed:
                _isImporting ? null : _importProject,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.upload_file_outlined,
                  ),
            label: Text(
              _isImporting
                  ? 'Import...'
                  : 'Importer Microsoft Project',
            ),
          ),
        );
      },
    );
  }

  Widget? _buildCreateProjectButton() {
    return FutureBuilder<ProjectListResult>(
      future: _projectListFuture,
      builder: (context, snapshot) {
        if (snapshot.data?.canCreateProjects !=
            true) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(
          onPressed: _createProject,
          icon: const Icon(Icons.add),
          label: const Text(
            'Nouveau projet',
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    ProjectListResult result,
  ) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_off_outlined,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                result.canCreateProjects
                    ? 'Aucun projet créé'
                    : 'Aucun projet attribué',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                result.canCreateProjects
                    ? 'Créez votre premier projet '
                        'Planner.'
                    : 'Un Manager doit vous ajouter '
                        'à un projet avant qu’il '
                        'apparaisse ici.',
                textAlign: TextAlign.center,
              ),
              if (result.canCreateProjects) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _createProject,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Créer un projet',
                  ),
                ),
              ],
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
          _buildImportAction(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _refreshProjects,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip:
                AuthSession.instance.email == null
                    ? 'Déconnexion'
                    : 'Déconnexion '
                        '(${AuthSession.instance.email})',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton:
          _buildCreateProjectButton(),
      body: FutureBuilder<ProjectListResult>(
        future: _projectListFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erreur lors du chargement des '
                'projets : ${snapshot.error}',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .error,
                ),
              ),
            );
          }

          final result = snapshot.data;

          if (result == null) {
            return const Center(
              child: Text(
                'Aucune donnée projet reçue.',
              ),
            );
          }

          if (result.projects.isEmpty) {
            return _buildEmptyState(result);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: result.projects.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildProjectCard(
                result.projects[index],
              );
            },
          );
        },
      ),
    );
  }
}

class _ImportPreviewChip
    extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ImportPreviewChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ImportPreviewDates
    extends StatelessWidget {
  final ProjectImportPreview preview;

  const _ImportPreviewDates({
    required this.preview,
  });

  String _formatDate(DateTime? value) {
    if (value == null) return '-';

    return DateFormat('dd/MM/yyyy')
        .format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        Text(
          'Début : '
          '${_formatDate(preview.startDate)}',
        ),
        Text(
          'Fin : '
          '${_formatDate(preview.endDate)}',
        ),
        Text(
          'Exceptions : '
          '${preview.calendarExceptionCount}',
        ),
        Text(
          'Périodes : '
          '${preview.calendarPeriodCount}',
        ),
      ],
    );
  }
}

class _ImportWarningTile
    extends StatelessWidget {
  final ProjectImportWarning warning;

  const _ImportWarningTile({
    required this.warning,
  });

  @override
  Widget build(BuildContext context) {
    final isError = warning.isError;
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Colors.orange.shade800;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : Icons.warning_amber_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              warning.message,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
