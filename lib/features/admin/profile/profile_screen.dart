import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/viewmodels/global_sync_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart'; // Para SyncProgress
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _photoUrlController;
  late TextEditingController _whatsappController;
  late TextEditingController _tenantController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _photoUrlController = TextEditingController();
    _whatsappController = TextEditingController();
    _tenantController = TextEditingController();

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
        _whatsappController.text = data['whatsappNumber'] as String? ?? '';
        _tenantController.text = data['tenantId'] as String? ?? '';
      } else if (mounted) {
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
    _whatsappController.dispose();
    _tenantController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final user = ref.read(authViewModelProvider).valueOrNull;
    if (user == null || user.email == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: kIsWeb, // Necessário no Web para acessar bytes
      );

      if (result != null && result.files.single.path != null ||
          (kIsWeb && result?.files.single.bytes != null)) {
        setState(() => _isLoading = true);

        final file = result!.files.single;
        final storage = ref.read(saasPhotoStorageProvider);

        final String? downloadUrl = await storage.uploadProfileImage(
          tenantId: _tenantController.text.trim(),
          email: user.email!,
          localPath: file.path,
          bytes: file.bytes,
        );

        if (downloadUrl != null && mounted) {
          setState(() {
            _photoUrlController.text = downloadUrl;
          });
          // Opcional: Salvar logo após upload
          await _save();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final user = ref.read(authViewModelProvider).valueOrNull;
    if (user == null || user.email == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(userRepositoryProvider).updateUserData(user.email!, {
        'displayName': _nameController.text.trim(),
        'photoURL': _photoUrlController.text.trim(),
        'whatsappNumber': _whatsappController.text.trim(),
        'tenantId': _tenantController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
      subtitle: 'Configura\u00e7\u00f5es pessoais do seu painel',
      maxWidth: 600,
      useAppBar: true,
      actions: [
        if (!_isLoading)
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _save,
            tooltip: 'Salvar',
          ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar Section
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: AppTokens.accentBlue.withOpacity(0.1),
                        backgroundImage: _photoUrlController.text.isNotEmpty
                            ? NetworkImage(_photoUrlController.text)
                            : null,
                        child: _photoUrlController.text.isEmpty
                            ? Text(
                                (_nameController.text.isNotEmpty
                                        ? _nameController.text
                                        : (user?.email ?? 'U'))[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: AppTokens.accentBlue,
                                ),
                              )
                            : null,
                      ),
                      InkWell(
                        onTap: _pickProfileImage,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTokens.accentBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space32),

                  // User & Tenant Info Card
                  Card(
                    elevation: 0,
                    color: AppTokens.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTokens.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.space24),
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
                            'Tipo de Conta',
                            role.label,
                            Icons.admin_panel_settings_outlined,
                          ),
                          const Divider(height: AppTokens.space24),
                          _buildInfoRow(
                            'Status de Sincroniza\u00e7\u00e3o',
                            _tenantController.text.isEmpty ? 'Offline (Apenas Local)' : 'Online (Nuvem Ativa)',
                            _tenantController.text.isEmpty ? Icons.cloud_off : Icons.cloud_done,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTokens.space32),
                  
                  // ✨ SEÇÃO DE SINCRONIZAÇÃO TOTAL
                  _buildGlobalSyncCard(context, ref),

                  const SizedBox(height: AppTokens.space32),

                  // Editable Fields
                  _buildSectionTitle('Informa\u00e7\u00f5es de Exibi\u00e7\u00e3o'),
                  const SizedBox(height: AppTokens.space12),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Nome de Exibi\u00e7\u00e3o',
                    icon: Icons.person_outline,
                    hint: 'Seu nome completo ou apelido',
                  ),
                  const SizedBox(height: AppTokens.space16),
                  _buildTextField(
                    controller: _whatsappController,
                    label: 'WhatsApp de Vendas',
                    icon: Icons.phone_android_outlined,
                    hint: 'DDI + DDD + N\u00famero (ex: 5511999999999)',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppTokens.space16),
                  _buildTextField(
                    controller: _tenantController,
                    label: 'ID da Empresa (SaaS ID)',
                    icon: Icons.business_outlined,
                    hint: 'ex: vitoriana_loja_01',
                  ),
                  const SizedBox(height: AppTokens.space16),
                  _buildTextField(
                    controller: _photoUrlController,
                    label: 'Link da Foto de Perfil',
                    icon: Icons.link_outlined,
                    hint: 'https://link-da-sua-imagem.png',
                    onChanged: (val) => setState(() {}),
                  ),

                  const SizedBox(height: AppTokens.space48),

                  // Logout Action
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryButton(
                      onPressed: () => ref.read(authViewModelProvider.notifier).signOut(),
                      label: 'SAIR DA CONTA',
                      icon: Icons.logout_rounded,
                      // Custom color for logout
                    ),
                  ),
                  const SizedBox(height: AppTokens.space48),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : Container(
              padding: const EdgeInsets.all(AppTokens.space24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: AppPrimaryButton(
                  label: 'SALVAR PERFIL',
                  icon: Icons.check_circle_outline,
                  onPressed: _save,
                ),
              ),
            ),
    );
  }

  Widget _buildGlobalSyncCard(BuildContext context, WidgetRef ref) {
    final syncProgress = ref.watch(syncProgressProvider);
    final isSyncing = syncProgress.isSyncing;

    return Card(
      elevation: 0,
      color: AppTokens.accentBlue.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTokens.accentBlue, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_sync, color: AppTokens.accentBlue),
                SizedBox(width: 12),
                Text(
                  'Sincroniza\u00e7\u00e3o Total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTokens.accentBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space12),
            const Text(
              'Gerencie todos os dados do seu catálogo na nuvem de uma vez: Categorias, Cole\u00e7\u00f5es, Produtos e Fotos.',
              style: TextStyle(fontSize: 13, color: AppTokens.textMuted),
            ),
            const SizedBox(height: AppTokens.space24),
            
            if (isSyncing) ...[
              LinearProgressIndicator(
                value: syncProgress.progress,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                syncProgress.message,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTokens.space24),
            ],

            Row(
              children: [
                Expanded(
                  child: AppPrimaryButton(
                    onPressed: isSyncing 
                      ? null 
                      : () => ref.read(globalSyncViewModelProvider.notifier).syncUpEverything(),
                    icon: Icons.cloud_upload_outlined,
                    label: 'SUBIR TUDO',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPrimaryButton(
                    onPressed: isSyncing 
                      ? null 
                      : () => ref.read(globalSyncViewModelProvider.notifier).syncDownEverything(),
                    icon: Icons.cloud_download_outlined,
                    label: 'BAIXAR TUDO',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: AppTokens.textMuted,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    Function(String)? onChanged,
    TextInputType? keyboardType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
            prefixIcon: Icon(icon, size: 20, color: isDark ? AppTokens.vibrantCyan : AppTokens.electricBlue),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTokens.electricBlue, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppTokens.accentBlue),
        const SizedBox(width: AppTokens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppTokens.textMuted),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
