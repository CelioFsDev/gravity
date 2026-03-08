import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _photoUrlController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _photoUrlController = TextEditingController();

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    final user = ref.read(authViewModelProvider).valueOrNull;
    if (user == null || user.email == null) return;

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email!.trim().toLowerCase())
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        _nameController.text = data['displayName'] as String? ?? '';
        _photoUrlController.text = data['photoURL'] as String? ?? '';
      } else if (mounted) {
        // Use data from auth if firestore doc doesn't exist yet
        _nameController.text = user.displayName ?? '';
        _photoUrlController.text = user.photoURL ?? '';
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(authViewModelProvider).valueOrNull;
    if (user == null || user.email == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(userRepositoryProvider).updateUserData(user.email!, {
        'displayName': _nameController.text.trim(),
        'photoURL': _photoUrlController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authViewModelProvider).valueOrNull;
    final role = ref.watch(currentRoleProvider);

    return AppScaffold(
      title: 'Meu Perfil',
      subtitle: 'Personalize como voc\u00ea aparece no sistema',
      maxWidth: 600,
      useAppBar: true,
      actions: [
        if (!_isLoading)
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
            tooltip: 'Salvar altera\u00e7\u00f5es',
          ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        backgroundImage: _photoUrlController.text.isNotEmpty
                            ? NetworkImage(_photoUrlController.text)
                            : null,
                        child: _photoUrlController.text.isEmpty
                            ? Text(
                                (_nameController.text.isNotEmpty
                                        ? _nameController.text
                                        : (user?.email ?? 'U'))[0]
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space24),

                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor.withAlpha(50),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            'E-mail',
                            user?.email ?? 'N/A',
                            Icons.email_outlined,
                          ),
                          const Divider(height: AppTokens.space24),
                          _buildInfoRow(
                            'Cargo',
                            role.label,
                            Icons.shield_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTokens.space24),

                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nome de Exibi\u00e7\u00e3o',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),

                  TextField(
                    controller: _photoUrlController,
                    decoration: InputDecoration(
                      labelText: 'URL da Foto',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      helperText: 'Insira a URL de uma imagem para seu avatar',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: AppTokens.space32),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(authViewModelProvider.notifier).signOut();
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'SAIR DO APLICATIVO',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: AppTokens.space12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }
}
