import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../projects/data/project_member_api.dart';
import '../../projects/data/project_member_model.dart';
import '../data/access_management_api.dart';
import '../data/access_management_model.dart';

const List<String> _roles = <String>[
  'Manager',
  'Lead',
  'Technician',
  'Viewer',
];

class AccessManagementView
    extends StatefulWidget {
  final bool isGlobalAdmin;
  final Future<void> Function()? onAccessChanged;

  const AccessManagementView({
    super.key,
    required this.isGlobalAdmin,
    this.onAccessChanged,
  });

  @override
  State<AccessManagementView> createState() =>
      _AccessManagementViewState();
}

class _AccessManagementViewState
    extends State<AccessManagementView> {
  final AccessManagementApi _api =
      AccessManagementApi();
  final ProjectMemberApi _memberApi =
      ProjectMemberApi();
  final TextEditingController _searchController =
      TextEditingController();

  late Future<AccessManagementOverview>
      _overviewFuture;

  int _selectedProjectId = 0;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadOverview() {
    _overviewFuture = _api.getOverview();
  }

  Future<void> _refresh() async {
    setState(_loadOverview);
  }

  Future<void> _refreshAfterMutation() async {
    await _refresh();
    await widget.onAccessChanged?.call();
  }

  Future<void> _addMember(
    AccessManagementOverview overview,
  ) async {
    if (_isMutating ||
        overview.projects.isEmpty) {
      return;
    }

    final emailController =
        TextEditingController();
    var projectId = _selectedProjectId == 0
        ? overview.projects.first.id
        : _selectedProjectId;
    var role = 'Viewer';

    final request =
        await showDialog<_AddAccessRequest>(
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
                  Icon(
                    Icons.person_add_alt_1_outlined,
                  ),
                  SizedBox(width: 10),
                  Text('Ajouter un accès'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: projectId,
                      decoration: const InputDecoration(
                        labelText: 'Projet',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.folder_outlined),
                      ),
                      items: overview.projects
                          .map(
                            (project) =>
                                DropdownMenuItem<int>(
                              value: project.id,
                              child: Text(
                                project.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          projectId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      autofocus: true,
                      keyboardType:
                          TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText:
                            'E-mail du compte Planner',
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
                      isExpanded: true,
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: 'Rôle projet',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.badge_outlined),
                      ),
                      items: _roles
                          .map(
                            (value) =>
                                DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                _roleLabel(value),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          role = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      role == 'Manager'
                          ? 'Le droit de créer des projets '
                              'sera effectif tant que ce '
                              'rôle Manager existe. Il ne '
                              'sera pas enregistré comme '
                              'permission durable.'
                          : _roleDescription(role),
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
                            _AddAccessRequest(
                              projectId: projectId,
                              email: email,
                              role: role,
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
      await _memberApi.addMember(
        projectId: request.projectId,
        request: ProjectMemberCreateRequest(
          email: request.email,
          role: request.role,
        ),
      );

      if (!mounted) return;

      _showSuccess(
        'Accès ajouté au projet.',
      );

      await _refreshAfterMutation();
    } catch (error) {
      if (!mounted) return;
      _showError(_formatError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<void> _editRole(
    AccessManagementMembership membership,
  ) async {
    if (_isMutating || membership.isOwner) {
      return;
    }

    var selectedRole = membership.role;

    final role = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            dialogContext,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Modifier le rôle projet',
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      membership.projectName,
                      style: Theme.of(dialogContext)
                          .textTheme
                          .titleMedium,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau rôle',
                        border: OutlineInputBorder(),
                      ),
                      items: _roles
                          .map(
                            (value) =>
                                DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                _roleLabel(value),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedRole = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      selectedRole == 'Manager'
                          ? 'Ce rôle autorise la création '
                              'tant qu’il est actif sur au '
                              'moins un projet.'
                          : _roleDescription(
                              selectedRole,
                            ),
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
                  onPressed:
                      selectedRole == membership.role
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
      await _memberApi.updateMember(
        projectId: membership.projectId,
        memberId: membership.memberId,
        request: ProjectMemberUpdateRequest(
          role: role,
        ),
      );

      if (!mounted) return;

      _showSuccess('Rôle mis à jour.');
      await _refreshAfterMutation();
    } catch (error) {
      if (!mounted) return;
      _showError(_formatError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<void> _removeMembership(
    AccessManagementUser user,
    AccessManagementMembership membership,
  ) async {
    if (_isMutating || membership.isOwner) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Retirer cet accès ?'),
          content: Text(
            '${user.effectiveName} perdra '
            'immédiatement l’accès à '
            '« ${membership.projectName} ».',
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
      await _memberApi.removeMember(
        projectId: membership.projectId,
        memberId: membership.memberId,
      );

      if (!mounted) return;

      _showSuccess('Accès retiré.');
      await _refreshAfterMutation();
    } catch (error) {
      if (!mounted) return;
      _showError(_formatError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<void> _editGlobalPermissions(
    AccessManagementUser user,
  ) async {
    if (_isMutating ||
        !widget.isGlobalAdmin) {
      return;
    }

    var isActive = user.isActive;
    var canCreate = user.canCreateProjects;
    var canManageResources =
        user.canManageResources;
    var isGlobalAdmin = user.isGlobalAdmin;

    final request =
        await showDialog<
            GlobalUserPermissionsUpdateRequest>(
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
                  Icon(
                    Icons.admin_panel_settings_outlined,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Permissions générales',
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      user.effectiveName,
                      style: Theme.of(dialogContext)
                          .textTheme
                          .titleMedium,
                    ),
                    Text(
                      user.email,
                      style: Theme.of(dialogContext)
                          .textTheme
                          .bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isActive,
                      title:
                          const Text('Compte actif'),
                      subtitle: const Text(
                        'Un compte désactivé ne doit '
                        'plus accéder à Planner.',
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          isActive = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      value: canCreate,
                      title: const Text(
                        'Création/import durable',
                      ),
                      subtitle: const Text(
                        'Permission indépendante des '
                        'rôles projet.',
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          canCreate = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      value: canManageResources,
                      title: const Text(
                        'Gestion du catalogue ressources',
                      ),
                      subtitle: const Text(
                        'Création, modification et '
                        'suppression du catalogue global.',
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          canManageResources = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      value: isGlobalAdmin,
                      title: const Text(
                        'Admin global',
                      ),
                      subtitle: const Text(
                        'Accès à tous les projets et '
                        'aux permissions générales.',
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          isGlobalAdmin = value;
                        });
                      },
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
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      GlobalUserPermissionsUpdateRequest(
                        isActive: isActive,
                        canCreateProjects: canCreate,
                        canManageResources:
                            canManageResources,
                        isGlobalAdmin: isGlobalAdmin,
                      ),
                    );
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

    if (!mounted || request == null) return;

    setState(() {
      _isMutating = true;
    });

    try {
      await _api.updateGlobalPermissions(
        userId: user.userId,
        request: request,
      );

      if (!mounted) return;

      _showSuccess(
        'Permissions générales mises à jour.',
      );

      await _refreshAfterMutation();
    } catch (error) {
      if (!mounted) return;
      _showError(_formatError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  List<AccessManagementUser> _filteredUsers(
    AccessManagementOverview overview,
  ) {
    final query =
        _searchController.text.trim().toLowerCase();

    return overview.users.where((user) {
      final matchesProject =
          _selectedProjectId == 0 ||
              user.memberships.any(
                (membership) =>
                    membership.projectId ==
                        _selectedProjectId,
              );

      if (!matchesProject) return false;

      if (query.isEmpty) return true;

      return user.email.toLowerCase().contains(query) ||
          (user.displayName ?? '')
              .toLowerCase()
              .contains(query) ||
          user.memberships.any(
            (membership) =>
                membership.projectName
                    .toLowerCase()
                    .contains(query) ||
                membership.role
                    .toLowerCase()
                    .contains(query),
          );
    }).toList();
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    return FutureBuilder<AccessManagementOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return _AccessErrorState(
            message: _formatError(snapshot.error!),
            onRetry: _refresh,
          );
        }

        final overview = snapshot.data;

        if (overview == null) {
          return const Center(
            child: Text(
              'Aucune donnée d’accès reçue.',
            ),
          );
        }

        final users = _filteredUsers(overview);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                10,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment:
                        WrapCrossAlignment.center,
                    children: [
                      Chip(
                        avatar: const Icon(
                          Icons.folder_outlined,
                          size: 17,
                        ),
                        label: Text(
                          '${overview.projects.length} '
                          'projet(s) administrable(s)',
                        ),
                      ),
                      Chip(
                        avatar: const Icon(
                          Icons.people_outline,
                          size: 17,
                        ),
                        label: Text(
                          '${overview.users.length} '
                          'utilisateur(s)',
                        ),
                      ),
                      if (overview.isGlobalAdmin)
                        const Chip(
                          avatar: Icon(
                            Icons.shield_outlined,
                            size: 17,
                          ),
                          label: Text(
                            'Administration globale',
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed:
                            _isMutating ? null : _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Rafraîchir'),
                      ),
                      FilledButton.icon(
                        onPressed: _isMutating ||
                                overview.projects.isEmpty
                            ? null
                            : () => _addMember(overview),
                        icon: const Icon(
                          Icons.person_add_alt_1,
                        ),
                        label:
                            const Text('Ajouter un accès'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final projectFilter =
                          DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue:
                            _selectedProjectId,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Filtrer par projet',
                          border:
                              OutlineInputBorder(),
                          isDense: true,
                        ),
                        selectedItemBuilder: (context) {
                          return <Widget>[
                            const Align(
                              alignment:
                                  Alignment.centerLeft,
                              child: Text(
                                'Tous les projets',
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                            ...overview.projects.map(
                              (project) => Align(
                                alignment:
                                    Alignment.centerLeft,
                                child: Text(
                                  project.name,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ];
                        },
                        items: [
                          const DropdownMenuItem<int>(
                            value: 0,
                            child: Text(
                              'Tous les projets',
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                          ...overview.projects.map(
                            (project) =>
                                DropdownMenuItem<int>(
                              value: project.id,
                              child: Text(
                                project.name,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedProjectId =
                                value ?? 0;
                          });
                        },
                      );

                      final searchField = TextField(
                        controller: _searchController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Rechercher un utilisateur',
                          hintText:
                              'Nom, e-mail, projet ou rôle',
                          border:
                              OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                      );

                      if (constraints.maxWidth < 760) {
                        return Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            projectFilter,
                            const SizedBox(height: 10),
                            searchField,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          SizedBox(
                            width: 330,
                            child: projectFilter,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: searchField),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: users.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun utilisateur ne '
                        'correspond aux filtres.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _AccessUserCard(
                          user: users[index],
                          canManageGlobalPermissions:
                              overview
                                  .canManageGlobalPermissions,
                          isBusy: _isMutating,
                          onEditGlobal: () =>
                              _editGlobalPermissions(
                            users[index],
                          ),
                          onEditMembership: _editRole,
                          onRemoveMembership:
                              (membership) =>
                                  _removeMembership(
                            users[index],
                            membership,
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

class _AccessUserCard extends StatelessWidget {
  final AccessManagementUser user;
  final bool canManageGlobalPermissions;
  final bool isBusy;
  final VoidCallback onEditGlobal;
  final ValueChanged<AccessManagementMembership>
      onEditMembership;
  final ValueChanged<AccessManagementMembership>
      onRemoveMembership;

  const _AccessUserCard({
    required this.user,
    required this.canManageGlobalPermissions,
    required this.isBusy,
    required this.onEditGlobal,
    required this.onEditMembership,
    required this.onRemoveMembership,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    _initials(user),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.effectiveName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                      ),
                      if (user.displayName != null)
                        Text(
                          user.email,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
                        ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (!user.isActive)
                      const Chip(
                        avatar: Icon(
                          Icons.block,
                          size: 16,
                        ),
                        label:
                            Text('Compte désactivé'),
                      ),
                    if (user.isGlobalAdmin)
                      const Chip(
                        avatar: Icon(
                          Icons.shield_outlined,
                          size: 16,
                        ),
                        label:
                            Text('Admin global'),
                      ),
                    if (user
                        .canCreateProjectsEffectively)
                      Chip(
                        avatar: const Icon(
                          Icons.add_business_outlined,
                          size: 16,
                        ),
                        label: Text(
                          _creationPermissionLabel(user),
                        ),
                      ),
                    if (user.canManageResources)
                      const Chip(
                        avatar: Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                        ),
                        label:
                            Text('Catalogue ressources'),
                      ),
                    if (canManageGlobalPermissions)
                      IconButton(
                        tooltip:
                            'Permissions générales',
                        onPressed:
                            isBusy ? null : onEditGlobal,
                        icon: const Icon(
                          Icons.admin_panel_settings_outlined,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (user.memberships.isEmpty)
              Text(
                'Aucun rattachement projet.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              )
            else
              ...user.memberships.map(
                (membership) =>
                    _MembershipRow(
                  membership: membership,
                  isBusy: isBusy,
                  onEdit: () =>
                      onEditMembership(membership),
                  onRemove: () =>
                      onRemoveMembership(membership),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MembershipRow extends StatelessWidget {
  final AccessManagementMembership membership;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _MembershipRow({
    required this.membership,
    required this.isBusy,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        membership.isOwner
            ? Icons.workspace_premium_outlined
            : Icons.folder_outlined,
      ),
      title: Text(membership.projectName),
      subtitle: Text(
        membership.isOwner
            ? 'Propriétaire — droits complets'
            : _roleDescription(membership.role),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(
              membership.isOwner
                  ? 'Propriétaire'
                  : _roleLabel(membership.role),
            ),
            visualDensity:
                VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          if (membership.isOwner)
            const Tooltip(
              message:
                  'La propriété doit être transférée '
                  'avant toute rétrogradation.',
              child: Icon(Icons.lock_outline),
            )
          else
            PopupMenuButton<_MembershipAction>(
              enabled: !isBusy,
              onSelected: (action) {
                switch (action) {
                  case _MembershipAction.edit:
                    onEdit();
                  case _MembershipAction.remove:
                    onRemove();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _MembershipAction.edit,
                  child: Text('Modifier le rôle'),
                ),
                PopupMenuItem(
                  value: _MembershipAction.remove,
                  child: Text('Retirer du projet'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _MembershipAction {
  edit,
  remove,
}

class _AddAccessRequest {
  final int projectId;
  final String email;
  final String role;

  const _AddAccessRequest({
    required this.projectId,
    required this.email,
    required this.role,
  });
}

class _AccessErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _AccessErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 44,
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
  final at = value.indexOf('@');
  final dot = value.lastIndexOf('.');

  return at > 0 &&
      dot > at + 1 &&
      dot < value.length - 1;
}

String _initials(AccessManagementUser user) {
  final source =
      user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : user.email.split('@').first;

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

String _creationPermissionLabel(
  AccessManagementUser user,
) {
  if (user.isGlobalAdmin) {
    return 'Création par Admin';
  }

  if (user.canCreateProjects) {
    return 'Création durable';
  }

  if (user.memberships.any(
    (membership) => membership.isOwner,
  )) {
    return 'Création par propriété';
  }

  return 'Création par rôle Manager';
}

String _roleLabel(String role) {
  return switch (role) {
    'Manager' => 'Manager',
    'Lead' => 'Lead',
    'Technician' => 'Technicien',
    'Viewer' => 'Viewer / Client',
    _ => role,
  };
}

String _roleDescription(String role) {
  return switch (role) {
    'Manager' =>
      'Peut gérer le planning, les membres et le projet.',
    'Lead' =>
      'Peut modifier le planning, les tâches et le calendrier.',
    'Technician' =>
      'Accès opérationnel actuellement en lecture seule.',
    'Viewer' =>
      'Consultation du projet en lecture seule.',
    _ => 'Rôle projet.',
  };
}

String _formatError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;

    if (data is String &&
        data.trim().isNotEmpty) {
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
    }

    return switch (error.response?.statusCode) {
      401 => 'Votre session a expiré.',
      403 =>
        'Vous n’êtes pas autorisé à gérer ces accès.',
      404 =>
        'Utilisateur, projet ou membre introuvable.',
      _ => 'Impossible de traiter la demande.',
    };
  }

  return 'Une erreur inattendue est survenue.';
}
