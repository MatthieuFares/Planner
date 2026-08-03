import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/project_member_api.dart';
import '../data/project_member_model.dart';

const List<String> _projectRoles = <String>[
  'Manager',
  'Lead',
  'Technician',
  'Viewer',
];

class ProjectMembersView extends StatefulWidget {
  final int projectId;

  const ProjectMembersView({
    super.key,
    required this.projectId,
  });

  @override
  State<ProjectMembersView> createState() =>
      _ProjectMembersViewState();
}

class _ProjectMembersViewState
    extends State<ProjectMembersView> {
  final ProjectMemberApi _api = ProjectMemberApi();

  late Future<List<ProjectMemberModel>> _membersFuture;

  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() {
    _membersFuture = _api.getMembers(
      widget.projectId,
    );
  }

  Future<void> _refresh() async {
    setState(_loadMembers);
  }

  Future<void> _showAddMemberDialog() async {
    if (_isMutating) return;

    final emailController = TextEditingController();
    var selectedRole = 'Viewer';

    final request =
        await showDialog<ProjectMemberCreateRequest>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            dialogContext,
            setDialogState,
          ) {
            final email =
                emailController.text.trim();

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1_outlined),
                  SizedBox(width: 10),
                  Text('Ajouter un membre'),
                ],
              ),
              content: SizedBox(
                width: 470,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      autofocus: true,
                      keyboardType:
                          TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText:
                            'E-mail du compte Planner',
                        hintText:
                            'prenom.nom@entreprise.fr',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.email_outlined),
                      ),
                      onChanged: (_) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Rôle dans le projet',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.badge_outlined),
                      ),
                      items: _projectRoles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(
                            _roleLabel(role),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedRole = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _RoleDescription(
                      role: selectedRole,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Le compte doit déjà exister dans '
                      'Planner avant son ajout au projet.',
                      style: Theme.of(dialogContext)
                          .textTheme
                          .bodySmall,
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
                  onPressed: _looksLikeEmail(email)
                      ? () {
                          Navigator.of(dialogContext).pop(
                            ProjectMemberCreateRequest(
                              email: email,
                              role: selectedRole,
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(
                    Icons.person_add_alt_1,
                  ),
                  label: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();

    if (!mounted || request == null) return;

    setState(() {
      _isMutating = true;
    });

    try {
      await _api.addMember(
        projectId: widget.projectId,
        request: request,
      );

      if (!mounted) return;

      setState(_loadMembers);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Membre ajouté au projet.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showError(
        _formatMemberError(
          error,
          fallback:
              'Impossible d’ajouter ce membre.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<void> _showEditRoleDialog(
    ProjectMemberModel member,
  ) async {
    if (_isMutating || member.isOwner) return;

    var selectedRole = member.role;

    final role = await showDialog<String>(
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
                  Icon(Icons.manage_accounts_outlined),
                  SizedBox(width: 10),
                  Text('Modifier le rôle'),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      member.effectiveName,
                      style: Theme.of(dialogContext)
                          .textTheme
                          .titleMedium,
                    ),
                    if (member.displayName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        member.email,
                        style: Theme.of(dialogContext)
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau rôle',
                        border: OutlineInputBorder(),
                      ),
                      items: _projectRoles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(
                            _roleLabel(role),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedRole = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _RoleDescription(
                      role: selectedRole,
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
                  onPressed:
                      selectedRole == member.role
                          ? null
                          : () {
                              Navigator.of(
                                dialogContext,
                              ).pop(selectedRole);
                            },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || role == null) return;

    setState(() {
      _isMutating = true;
    });

    try {
      await _api.updateMember(
        projectId: widget.projectId,
        memberId: member.id,
        request: ProjectMemberUpdateRequest(
          role: role,
        ),
      );

      if (!mounted) return;

      setState(_loadMembers);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Rôle du membre mis à jour.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showError(
        _formatMemberError(
          error,
          fallback:
              'Impossible de modifier ce rôle.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<void> _removeMember(
    ProjectMemberModel member,
  ) async {
    if (_isMutating || member.isOwner) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Retirer le membre ?',
          ),
          content: Text(
            '${member.effectiveName} perdra immédiatement '
            'l’accès à ce projet.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(
                Icons.person_remove_outlined,
              ),
              label: const Text('Retirer'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _isMutating = true;
    });

    try {
      await _api.removeMember(
        projectId: widget.projectId,
        memberId: member.id,
      );

      if (!mounted) return;

      setState(_loadMembers);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Membre retiré du projet.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showError(
        _formatMemberError(
          error,
          fallback:
              'Impossible de retirer ce membre.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProjectMemberModel>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return _MembersErrorState(
            message: _formatMemberError(
              snapshot.error!,
              fallback:
                  'Impossible de charger les membres.',
            ),
            onRetry: _refresh,
          );
        }

        final members =
            snapshot.data ?? const <ProjectMemberModel>[];

        final managerCount = members
            .where(
              (member) => member.role == 'Manager',
            )
            .length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                8,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment:
                    WrapCrossAlignment.center,
                children: [
                  Text(
                    'Membres du projet',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  Chip(
                    avatar: const Icon(
                      Icons.people_outline,
                      size: 18,
                    ),
                    label: Text(
                      '${members.length} membre(s)',
                    ),
                  ),
                  Chip(
                    avatar: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 18,
                    ),
                    label: Text(
                      '$managerCount Manager(s)',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _isMutating ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rafraîchir'),
                  ),
                  FilledButton.icon(
                    onPressed: _isMutating
                        ? null
                        : _showAddMemberDialog,
                    icon: _isMutating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.person_add_alt_1,
                          ),
                    label: const Text(
                      'Ajouter un membre',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: members.isEmpty
                  ? _EmptyMembersState(
                      onAddMember:
                          _showAddMemberDialog,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: members.length,
                      separatorBuilder: (
                        context,
                        index,
                      ) {
                        return const SizedBox(height: 8);
                      },
                      itemBuilder: (context, index) {
                        final member = members[index];

                        return _MemberCard(
                          member: member,
                          isBusy: _isMutating,
                          onEdit: () =>
                              _showEditRoleDialog(
                            member,
                          ),
                          onRemove: () =>
                              _removeMember(member),
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

class _MemberCard extends StatelessWidget {
  final ProjectMemberModel member;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.isBusy,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final createdLabel =
        member.createdAt.millisecondsSinceEpoch == 0
            ? null
            : DateFormat('dd/MM/yyyy').format(
                member.createdAt.toLocal(),
              );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(
                _initials(member),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment:
                        WrapCrossAlignment.center,
                    children: [
                      Text(
                        member.effectiveName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                      ),
                      if (member.isOwner)
                        const Chip(
                          avatar: Icon(
                            Icons.workspace_premium_outlined,
                            size: 17,
                          ),
                          label: Text('Propriétaire'),
                          visualDensity:
                              VisualDensity.compact,
                        ),
                    ],
                  ),
                  if (member.displayName != null)
                    Text(
                      member.email,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  if (createdLabel != null)
                    Text(
                      member.isOwner
                          ? 'Compte créé le $createdLabel'
                          : 'Ajouté au projet le '
                              '$createdLabel',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _RoleChip(role: member.role),
            const SizedBox(width: 8),
            if (member.isOwner)
              const Tooltip(
                message:
                    'Le propriétaire reste Manager '
                    'et ne peut pas être retiré.',
                child: Icon(
                  Icons.lock_outline,
                ),
              )
            else
              PopupMenuButton<_MemberAction>(
                enabled: !isBusy,
                tooltip: 'Actions du membre',
                onSelected: (action) {
                  switch (action) {
                    case _MemberAction.editRole:
                      onEdit();
                    case _MemberAction.remove:
                      onRemove();
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem<_MemberAction>(
                      value:
                          _MemberAction.editRole,
                      child: ListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        leading: Icon(
                          Icons.manage_accounts_outlined,
                        ),
                        title: Text(
                          'Modifier le rôle',
                        ),
                      ),
                    ),
                    PopupMenuItem<_MemberAction>(
                      value: _MemberAction.remove,
                      child: ListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        leading: Icon(
                          Icons.person_remove_outlined,
                        ),
                        title: Text(
                          'Retirer du projet',
                        ),
                      ),
                    ),
                  ];
                },
              ),
          ],
        ),
      ),
    );
  }
}

enum _MemberAction {
  editRole,
  remove,
}

class _RoleChip extends StatelessWidget {
  final String role;

  const _RoleChip({
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _roleDescription(role),
      child: Chip(
        avatar: Icon(
          _roleIcon(role),
          size: 17,
        ),
        label: Text(
          _roleLabel(role),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _RoleDescription extends StatelessWidget {
  final String role;

  const _RoleDescription({
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            _roleIcon(role),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _roleDescription(role),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMembersState extends StatelessWidget {
  final VoidCallback onAddMember;

  const _EmptyMembersState({
    required this.onAddMember,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.group_add_outlined,
                size: 48,
              ),
              const SizedBox(height: 10),
              const Text(
                'Aucun membre supplémentaire',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ajoute un compte Planner pour '
                'partager ce projet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAddMember,
                icon: const Icon(
                  Icons.person_add_alt_1,
                ),
                label: const Text(
                  'Ajouter un membre',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _MembersErrorState({
    required this.message,
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
                Icons.error_outline,
                size: 42,
                color:
                    Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 10),
              Text(
                message,
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

bool _looksLikeEmail(String value) {
  final atIndex = value.indexOf('@');
  final dotIndex = value.lastIndexOf('.');

  return atIndex > 0 &&
      dotIndex > atIndex + 1 &&
      dotIndex < value.length - 1;
}

String _initials(ProjectMemberModel member) {
  final source = member.displayName?.trim().isNotEmpty == true
      ? member.displayName!.trim()
      : member.email.split('@').first;

  final parts = source
      .split(RegExp(r'[\s._-]+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();

  if (parts.isEmpty) return '?';

  return parts
      .map((part) => part[0].toUpperCase())
      .join();
}

String _roleLabel(String role) {
  switch (role) {
    case 'Manager':
      return 'Manager';
    case 'Lead':
      return 'Lead';
    case 'Technician':
      return 'Technicien';
    case 'Viewer':
      return 'Viewer / Client';
    default:
      return role;
  }
}

IconData _roleIcon(String role) {
  switch (role) {
    case 'Manager':
      return Icons.admin_panel_settings_outlined;
    case 'Lead':
      return Icons.account_tree_outlined;
    case 'Technician':
      return Icons.engineering_outlined;
    case 'Viewer':
      return Icons.visibility_outlined;
    default:
      return Icons.person_outline;
  }
}

String _roleDescription(String role) {
  switch (role) {
    case 'Manager':
      return 'Peut modifier le planning, gérer les '
          'membres et supprimer le projet.';
    case 'Lead':
      return 'Peut modifier le planning, les tâches, '
          'les assignations et le calendrier.';
    case 'Technician':
      return 'Accès opérationnel limité. Les droits '
          'd’avancement et de commentaires pourront '
          'être ajoutés dans une étape dédiée.';
    case 'Viewer':
      return 'Consultation en lecture seule du projet, '
          'du Gantt, du calendrier et des baselines.';
    default:
      return 'Rôle projet.';
  }
}

String _formatMemberError(
  Object error, {
  required String fallback,
}) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    final message = _extractBackendMessage(data);

    if (message != null) {
      return message;
    }

    if (statusCode == 400) {
      return 'La demande est invalide.';
    }

    if (statusCode == 401) {
      return 'Votre session a expiré.';
    }

    if (statusCode == 403) {
      return 'Vous n’êtes pas autorisé à gérer '
          'les membres de ce projet.';
    }

    if (statusCode == 404) {
      return 'Projet, membre ou utilisateur '
          'introuvable.';
    }

    if (error.type ==
            DioExceptionType.connectionError ||
        error.type ==
            DioExceptionType.connectionTimeout ||
        error.type ==
            DioExceptionType.receiveTimeout ||
        error.type ==
            DioExceptionType.sendTimeout) {
      return 'Impossible de contacter l’API Planner.';
    }
  }

  return fallback;
}

String? _extractBackendMessage(dynamic data) {
  if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }

  if (data is Map) {
    for (final key in const [
      'message',
      'detail',
      'error',
      'title',
    ]) {
      final value = data[key];

      if (value is String &&
          value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final errors = data['errors'];

    if (errors is Map) {
      final messages = <String>[];

      for (final value in errors.values) {
        if (value is List) {
          messages.addAll(
            value
                .whereType<String>()
                .where(
                  (message) =>
                      message.trim().isNotEmpty,
                ),
          );
        }
      }

      if (messages.isNotEmpty) {
        return messages.join(' ');
      }
    }
  }

  return null;
}
