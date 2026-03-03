import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/data/repositories/user_sync_repository.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
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

  Future<void> _syncUsers() async {
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
    if (error is! FirebaseFunctionsException) {
      return 'Erro ao sincronizar usuários.';
    }

    switch (error.code) {
      case 'permission-denied':
        return 'Apenas o administrador geral pode sincronizar usuários.';
      case 'unauthenticated':
        return 'Sessão expirada. Entre novamente.';
      case 'unavailable':
        return 'Serviço indisponível. Verifique a conexão.';
      default:
        return error.message ?? 'Erro ao sincronizar usuários.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRepository = ref.watch(userRepositoryProvider);
    final currentRole = ref.watch(currentRoleProvider);
    final currentEmail = ref.watch(authViewModelProvider).valueOrNull?.email;

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
          onPressed: () => context.push('/admin/settings/users/create-login'),
        ),
      ],
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: userRepository.getUsersStream(),
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
                            context.push('/admin/settings/users/create-login'),
                      ),
                      const Divider(height: 32),
                      _AdminActionTile(
                        icon: Icons.sync_outlined,
                        title: 'Sincronizar Logins Externos',
                        subtitle:
                            'Busca usuários criados via Google e atualiza permissões.',
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
    final roleStr = user['role'] as String;
    final role = UserRole.values.firstWhere(
      (item) => item.name == roleStr,
      orElse: () => UserRole.viewer,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          email,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                role.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<UserRole>(
          onSelected: (newRole) {
            ref.read(userRepositoryProvider).setUserRole(email, newRole);
          },
          itemBuilder: (context) => UserRole.values.map((item) {
            return PopupMenuItem(
              value: item,
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(item.label),
                ],
              ),
            );
          }).toList(),
          icon: const Icon(Icons.more_vert),
        ),
      ),
    );
  }
}
