import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/data/repositories/admin_user_account_repository.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/data/repositories/user_sync_repository.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  bool _isSyncing = false;
  bool _didAutoSync = false;

  @override
  void initState() {
    super.initState();
    _ensureCurrentUserDocument();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didAutoSync) return;
      _didAutoSync = true;
      _syncUsers(showFeedback: false);
    });
  }

  Future<void> _ensureCurrentUserDocument() async {
    final user = ref.read(authViewModelProvider).valueOrNull;
    final email = user?.email?.trim().toLowerCase() ?? '';
    if (user == null || email.isEmpty) return;

    try {
      await ref.read(userRepositoryProvider).ensureUserProfile(
        email: email,
        displayName: user.displayName ?? '',
        photoURL: user.photoURL ?? '',
        providerIds: user.providerData
            .map((provider) => provider.providerId)
            .whereType<String>()
            .toList(),
        authUid: user.uid,
        preferredRole: UserRole.superAdminEmails.contains(email)
            ? UserRole.admin
            : UserRole.viewer,
      );
    } catch (error) {
      debugPrint('Erro ao garantir documento do usuário: $error');
    }
  }

  Future<void> _syncUsers({bool showFeedback = true}) async {
    setState(() => _isSyncing = true);

    try {
      final result = await ref.read(userSyncRepositoryProvider).syncAuthUsers();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sincronização concluída. '
            '${result.created} novos, ${result.updated} atualizados.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_syncErrorMessage(error)),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  String _syncErrorMessage(Object error) {
    if (error is FirebaseException) {
      return error.message ?? 'Erro ao sincronizar usuários.';
    }

    if (error is! FirebaseFunctionsException) {
      return error.toString();
    }

    switch (error.code) {
      case 'permission-denied':
        return 'Apenas o administrador geral pode sincronizar usuários.';
      case 'unauthenticated':
        return 'Sessão expirada. Entre novamente.';
      case 'unavailable':
        return 'Serviço indisponível. Verifique a conexão.';
      case 'not-found':
        return 'As funções do Firebase não foram encontradas. Você as publicou via terminal (firebase deploy)?';
      default:
        return error.message ?? 'Erro ao sincronizar usuários.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRepository = ref.watch(userRepositoryProvider);
    final currentRole = ref.watch(currentRoleProvider);
    final currentEmail = ref.watch(authViewModelProvider).valueOrNull?.email;
    final currentTenantId = ref.watch(currentTenantProvider).valueOrNull?.id;
    final currentStoreId = ref.watch(currentStoreIdProvider).valueOrNull;

    if (!currentRole.canManageUsers(currentEmail)) {
      return const AppScaffold(
        title: 'Gerenciar Usuários',
        body: Center(child: Text('Acesso restrito ao administrador geral.')),
      );
    }

    return AppScaffold(
      title: 'Gerenciar Usuários',
      subtitle: 'Controle de acessos e perfis da equipe',
      maxWidth: 800,
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add_outlined),
          tooltip: 'Novo Usuário',
          onPressed: () => context.go('/admin/settings/users/create-login'),
        ),
      ],
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: userRepository.getUsersForTenantAndStoreStream(
          tenantId: currentTenantId ?? '',
          storeId: currentStoreId ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar usuários: ${snapshot.error}'),
            );
          }

          final users = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'Ações de Administrador',
                  child: Column(
                    children: [
                      _AdminActionTile(
                        icon: Icons.badge_outlined,
                        title: 'Cadastrar Novo Acesso',
                        subtitle:
                            'Cria login oficial (email/senha) no Firebase Auth.',
                        onTap: () =>
                            context.go('/admin/settings/users/create-login'),
                      ),
                      const Divider(height: 32),
                      _AdminActionTile(
                        icon: Icons.sync_outlined,
                        title: 'Sincronizar Logins Externos',
                        subtitle:
                            'Importa usuários antigos do Firebase Auth. Novos logins entram automaticamente.',
                        loading: _isSyncing,
                        onTap: _isSyncing ? null : _syncUsers,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 20,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'USUÁRIOS CADASTRADOS (${users.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (users.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Nenhum usuário encontrado.'),
                    ),
                  )
                else
                  ...users.map((user) => _UserRow(user: user)),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  const _AdminActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = user['email'] as String;
    final normalizedEmail = email.trim().toLowerCase();
    final currentEmail =
        ref.watch(authViewModelProvider).valueOrNull?.email?.trim().toLowerCase();
    final currentIsSuperAdmin =
        UserRole.superAdminEmails.contains(currentEmail);
    final displayName = user['displayName'] as String? ?? '';
    final photoURL = user['photoURL'] as String? ?? '';
    final tenantId = ref.watch(currentTenantProvider).valueOrNull?.id ?? '';
    final storeId = ref.watch(currentStoreIdProvider).valueOrNull ?? '';
    final roleStr = effectiveUserRoleName(
      user,
      tenantId: tenantId,
      storeId: storeId,
    );
    final providerIds = List<String>.from(user['providerIds'] ?? []);

    final role = UserRole.values.firstWhere(
      (item) => item.name == roleStr,
      orElse: () => UserRole.viewer,
    );

    final bool isDisabled = user['disabled'] as bool? ?? false;
    final isProtectedAccount =
        UserRole.superAdminEmails.contains(normalizedEmail) ||
        normalizedEmail == currentEmail ||
        (role == UserRole.admin && !currentIsSuperAdmin);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDisabled
              ? Colors.red.withAlpha(50)
              : Theme.of(context).dividerColor.withAlpha(50),
        ),
      ),
      color: isDisabled ? Colors.red.withAlpha(5) : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withAlpha(30),
              backgroundImage: photoURL.isNotEmpty
                  ? NetworkImage(photoURL)
                  : null,
              child: photoURL.isEmpty
                  ? Text(
                      (displayName.isNotEmpty ? displayName : email)[0]
                          .toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            if (isDisabled)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, size: 14, color: Colors.red),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName.isNotEmpty ? displayName : email,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isDisabled)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BLOQUEADO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (displayName.isNotEmpty)
              Text(
                email,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ...providerIds.map(
                  (id) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      id == 'google.com' ? Icons.g_mobiledata : Icons.password,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: isProtectedAccount
            ? const Tooltip(
                message: 'Conta protegida',
                child: Icon(Icons.lock_outline, size: 20),
              )
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _showEditDialog(context, ref);
                  if (value == 'delete') _showDeleteDialog(context, ref);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Alterar Perfil'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Remover Acesso',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(
      text: user['displayName'] as String? ?? '',
    );
    UserRole selectedRole = UserRole.values.firstWhere(
      (item) =>
          item.name ==
          effectiveUserRoleName(
            user,
            tenantId: ref.read(currentTenantProvider).valueOrNull?.id ?? '',
            storeId: ref.read(currentStoreIdProvider).valueOrNull ?? '',
          ),
      orElse: () => UserRole.viewer,
    );
    final currentEmail =
        ref.read(authViewModelProvider).valueOrNull?.email?.trim().toLowerCase();
    final canAssignAdmin = UserRole.superAdminEmails.contains(currentEmail);
    final assignableRoles = UserRole.values
        .where((role) => canAssignAdmin || role != UserRole.admin)
        .toList();
    if (!assignableRoles.contains(selectedRole)) {
      selectedRole = assignableRoles.contains(UserRole.operator)
          ? UserRole.operator
          : UserRole.seller;
    }
    bool isSuspended = user['disabled'] as bool? ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Alterar Perfil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome de Exibição',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Acesso Bloqueado'),
                subtitle: const Text('Impede o usuário de entrar no app'),
                activeThumbColor: Colors.red,
                value: isSuspended,
                onChanged: (val) => setState(() => isSuspended = val),
              ),
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nível de Acesso',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<UserRole>(
                initialValue: selectedRole,
                decoration: InputDecoration(
                  labelText: 'Perfil de Acesso',
                  prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: assignableRoles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedRole = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(adminUserAccountRepositoryProvider)
                    .updateUserAccess(
                      email: user['email'] as String,
                      displayName: nameController.text.trim(),
                      role: selectedRole.name,
                      disabled: isSuspended,
                      tenantId: ref.read(currentTenantProvider).valueOrNull?.id,
                      storeId: ref.read(currentStoreIdProvider).valueOrNull,
                    )
                    .then((_) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Usuário atualizado com sucesso.'),
                          ),
                        );
                      }
                    })
                    .catchError((error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _userAdminErrorMessage(error),
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                    });
              },
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Acesso?'),
        content: Text(
          'Deseja remover o acesso de ${user['email']} nesta empresa/loja?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(adminUserAccountRepositoryProvider)
                  .deleteUserAccount(
                    user['email'] as String,
                    tenantId: ref.read(currentTenantProvider).valueOrNull?.id,
                    storeId: ref.read(currentStoreIdProvider).valueOrNull,
                  )
                  .then((_) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Usuário excluído com sucesso.'),
                        ),
                      );
                    }
                  })
                  .catchError((error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _userAdminErrorMessage(error),
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  });
            },
            child: const Text('EXCLUIR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

String _userAdminErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Você não tem permissão para gerenciar usuários.';
      case 'failed-precondition':
        return error.message ?? 'Operação não permitida para este usuário.';
      case 'not-found':
        return 'Usuário não encontrado no Firebase Auth.';
      case 'unauthenticated':
        return 'Sua sessão expirou. Entre novamente.';
      default:
        return error.message ?? 'Erro ao gerenciar usuário.';
    }
  }

  return 'Erro ao gerenciar usuário.';
}
