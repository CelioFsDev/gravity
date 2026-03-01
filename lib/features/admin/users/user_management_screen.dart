import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepository = ref.watch(userRepositoryProvider);
    final currentRole = ref.watch(currentRoleProvider);

    if (currentRole != UserRole.admin) {
      return const AppScaffold(
        title: 'Gerenciar Usuários',
        body: Center(child: Text('Acesso restrito para administradores.')),
      );
    }

    return AppScaffold(
      title: 'Gerenciar Usuários',
      subtitle: 'Defina quem pode editar seu catálogo',
      maxWidth: 800,
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
                  title: 'Adicionar Novo Usuário',
                  child: _AddUserForm(),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Usuários Cadastrados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (users.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Nenhum usuário cadastrado.'),
                    ),
                  )
                else
                  ...users.map((user) => _UserRow(user: user)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddUserForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddUserForm> createState() => _AddUserFormState();
}

class _AddUserFormState extends ConsumerState<_AddUserForm> {
  final _emailController = TextEditingController();
  UserRole _selectedRole = UserRole.seller;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addUser() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('E-mail inválido')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(userRepositoryProvider).setUserRole(email, _selectedRole);
      _emailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário adicionado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar usuário: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'E-mail do Usuário',
            hintText: 'exemplo@gmail.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<UserRole>(
          value: _selectedRole,
          decoration: const InputDecoration(
            labelText: 'Permissão',
            prefixIcon: Icon(Icons.admin_panel_settings_outlined),
          ),
          items: UserRole.values.map((role) {
            return DropdownMenuItem(value: role, child: Text(role.label));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedRole = val);
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _addUser,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_outlined),
            label: const Text('Adicionar Permissão'),
          ),
        ),
      ],
    );
  }
}

class _UserRow extends ConsumerWidget {
  final Map<String, dynamic> user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = user['email'] as String;
    final roleStr = user['role'] as String;
    final role = UserRole.values.firstWhere(
      (e) => e.name == roleStr,
      orElse: () => UserRole.viewer,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Cargo: ${role.label}'),
        trailing: PopupMenuButton<UserRole>(
          onSelected: (newRole) {
            ref.read(userRepositoryProvider).setUserRole(email, newRole);
          },
          itemBuilder: (context) => UserRole.values.map((r) {
            return PopupMenuItem(value: r, child: Text(r.label));
          }).toList(),
          icon: const Icon(Icons.more_vert),
        ),
      ),
    );
  }
}
