import 'package:catalogo_ja/viewmodels/global_sync_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/settings_viewmodel.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/tenant_repository.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _storeNameController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _remotePhotoUrlController;
  late final TextEditingController _linktreeController;
  late final TextEditingController _instagramController;
  late final TextEditingController _companyInstagramController;
  late bool _isInitialSyncCompleted;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsViewModelProvider);
    _storeNameController = TextEditingController(text: settings.storeName);
    _whatsappController = TextEditingController(text: settings.whatsappNumber);
    _baseUrlController = TextEditingController(text: settings.publicBaseUrl);
    _remotePhotoUrlController = TextEditingController(
      text: settings.remoteImageBaseUrl,
    );
    _linktreeController = TextEditingController(text: settings.linktreeUrl);
    _instagramController = TextEditingController(text: settings.instagramUrl);
    _companyInstagramController = TextEditingController(
      text: settings.companyInstagramUrl,
    );
    _isInitialSyncCompleted = settings.isInitialSyncCompleted;
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _whatsappController.dispose();
    _baseUrlController.dispose();
    _remotePhotoUrlController.dispose();
    _linktreeController.dispose();
    _instagramController.dispose();
    _companyInstagramController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          storeName: _storeNameController.text,
          whatsappNumber: _whatsappController.text,
          publicBaseUrl: _baseUrlController.text,
          remoteImageBaseUrl: _remotePhotoUrlController.text,
          linktreeUrl: _linktreeController.text,
          instagramUrl: _instagramController.text,
          companyInstagramUrl: _companyInstagramController.text,
          isInitialSyncCompleted: _isInitialSyncCompleted,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configura\u00e7\u00f5es salvas com sucesso!'),
        ),
      );
    }
  }

  Future<void> _testPublicLink(String baseUrl) async {
    final catalogs = ref.read(catalogsViewModelProvider).value ?? [];
    String shareCode = 'TEST-CODE';

    try {
      final publicCatalog = catalogs.firstWhere(
        (c) => c.isPublic && c.shareCode.isNotEmpty,
      );
      shareCode = publicCatalog.shareCode;
    } catch (_) {
      // No public catalog found, using fake
    }

    // Clean base URL for testing
    var finalBaseUrl = baseUrl.trim();
    if (finalBaseUrl.endsWith('/')) {
      finalBaseUrl = finalBaseUrl.substring(0, finalBaseUrl.length - 1);
    }
    if (!finalBaseUrl.startsWith('http')) {
      finalBaseUrl = 'https://$finalBaseUrl';
    }

    final fullUrl = '$finalBaseUrl/c/$shareCode';
    final uri = Uri.parse(fullUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'N\u00e3o foi poss\u00edvel abrir a URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir link: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _findMyLostData() async {
    final email = ref.read(authViewModelProvider).valueOrNull?.email;
    if (email == null) return;
    final emailDoc = email.toLowerCase().trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final query = await FirebaseFirestore.instance
          .collection('products')
          .limit(1)
          .get();
      if (mounted) Navigator.pop(context); // Fecha loading

      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhum dado encontrado no banco global.'),
            ),
          );
        }
        return;
      }

      final legacyTenantId = query.docs.first.data()['tenantId'] as String?;
      if (legacyTenantId != null && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Resgate de Dados'),
            content: Text(
              'Detectamos produtos antigos sob o código: "$legacyTenantId".\nDeseja vincular sua conta a esses dados e reiniciar o app?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('RESGATAR E ENTRAR'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(emailDoc)
              .update({
                'tenantId': legacyTenantId,
                'tenantIds': FieldValue.arrayUnion([legacyTenantId]),
              });
          if (mounted) context.go('/admin/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppScaffold(
        showHeader: true,
        title: 'Ajustes',
        subtitle: 'Gerencie sua loja e o sistema',
        maxWidth: 800,
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.storefront_outlined), text: 'Minha Loja'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Configuração'),
            Tab(icon: Icon(Icons.build_circle_outlined), text: 'Manutenção'),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
        body: TabBarView(
          children: [
            _buildMyStoreTab(),
            _buildSettingsTab(),
            _buildMaintenanceTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyStoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: Column(
        children: [
          SectionCard(
            title: 'Identidade da Loja',
            child: Column(
              children: [
                const Text(
                  'Estas informações aparecerão no cabeçalho e rodapé dos seus catálogos PDF.',
                  style: TextStyle(fontSize: 13, color: AppTokens.textMuted),
                ),
                const SizedBox(height: 20),
                _buildField(
                  controller: _storeNameController,
                  label: 'Nome da Loja',
                  hint: 'Ex: Minha Loja Fashion',
                  icon: Icons.storefront_outlined,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _whatsappController,
                  label: 'WhatsApp de Vendas',
                  hint: '5511999999999',
                  icon: Icons.phone_outlined,
                  helper: 'Apenas números, com DDI (ex: 55)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionCard(
            title: 'Redes Sociais',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Links que aparecem na última página do catálogo PDF como botões clicáveis.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _linktreeController,
                  label: 'Link do Linktree',
                  hint: 'https://linktr.ee/sualoja',
                  icon: Icons.link_outlined,
                  helper: 'Link da sua página no Linktree',
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _instagramController,
                  label: 'Instagram da Loja',
                  hint: 'https://instagram.com/sualoja',
                  icon: Icons.camera_alt_outlined,
                  helper: 'Link do perfil da loja no Instagram',
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _companyInstagramController,
                  label: 'Instagram da Empresa',
                  hint: 'https://instagram.com/empresa',
                  icon: Icons.business_outlined,
                  helper: 'Link do perfil institucional da empresa',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStoreManagementSection(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              onPressed: _save,
              label: 'SALVAR DADOS DA LOJA',
              icon: Icons.save_outlined,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: Column(
        children: [
          SectionCard(
            title: 'Ajustes de Sistema',
            child: Column(
              children: [
                _buildField(
                  controller: _baseUrlController,
                  label: 'URL Base do Catálogo',
                  hint: 'https://seusite.com',
                  icon: Icons.language_outlined,
                  helper: 'Usado para gerar links de compartilhamento',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _buildLinkPreview(),
                const SizedBox(height: 16),
                _buildField(
                  controller: _remotePhotoUrlController,
                  label: 'URL Base para Fotos (Nuvem)',
                  hint: 'https://seusite.com/fotos',
                  icon: Icons.cloud_download_outlined,
                  helper: 'Pasta onde as fotos estão hospedadas',
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Carga Inicial Concluída'),
                  subtitle: const Text(
                    'Se desativado, o app exigirá importação do ZIP para iniciar.',
                  ),
                  value: _isInitialSyncCompleted,
                  onChanged: (val) =>
                      setState(() => _isInitialSyncCompleted = val),
                  secondary: const Icon(Icons.cloud_sync_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              onPressed: _save,
              label: 'SALVAR CONFIGURAÇÕES',
              icon: Icons.save_outlined,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    final user = ref.watch(authViewModelProvider).valueOrNull;
    final canManage = ref
        .watch(currentRoleProvider)
        .canManageUsers(user?.email);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: Column(
        children: [
          if (canManage) ...[
            SectionCard(
              title: 'Gestão de Acesso',
              child: Column(
                children: [
                  const Text(
                    'Controle quem pode acessar o painel de administração e quais permissões cada pessoa possui.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryButton(
                      icon: Icons.people_outline,
                      label: 'Configurar Usuários',
                      onPressed: () => context.push('/admin/settings/users'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          SectionCard(
            title: 'Manutenção de Dados',
            child: Column(
              children: [
                const Text(
                  'Use esta ferramenta para escanear o banco de dados em busca de catálogos antigos que não aparecem na sua conta atual.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTokens.accentOrange,
                    ),
                    onPressed: _findMyLostData,
                    icon: const Icon(Icons.history_outlined),
                    label: const Text('ESCANEAR E RESGATAR DADOS'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionCard(
            title: 'Sincronização Global',
            child: Column(
              children: [
                const Text(
                  'Forçar sincronização de todos os dados locais com a nuvem.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ref
                            .read(globalSyncViewModelProvider.notifier)
                            .syncUpEverything(),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('SUBIR TUDO'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ref
                            .read(globalSyncViewModelProvider.notifier)
                            .syncDownEverything(),
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('BAIXAR TUDO'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Versão do App: 1.0.0',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLinkPreview() {
    return ValueListenableBuilder(
      valueListenable: _baseUrlController,
      builder: (context, value, _) {
        final url = value.text.trim();
        if (url.isEmpty) return const SizedBox.shrink();

        var displayUrl = url;
        if (displayUrl.endsWith('/')) {
          displayUrl = displayUrl.substring(0, displayUrl.length - 1);
        }
        if (!displayUrl.startsWith('http')) {
          displayUrl = 'https://$displayUrl';
        }

        return Container(
          padding: const EdgeInsets.all(AppTokens.space12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withAlpha(40),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Prévia do link público:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$displayUrl/c/XYZ123',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Testar link público'),
                  onPressed: () => _testPublicLink(displayUrl),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoreManagementSection() {
    final tenantAsync = ref.watch(currentTenantProvider);
    final user = ref.watch(authViewModelProvider).valueOrNull;

    return tenantAsync.when(
      data: (tenant) {
        if (tenant == null) return const SizedBox.shrink();
        final stores = tenant.stores;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.email?.trim().toLowerCase())
              .get(),
          builder: (context, snapshot) {
            final currentStore = snapshot.data?.data() as Map<String, dynamic>?;
            final currentStoreId =
                currentStore?['currentStoreId'] as String? ??
                (stores.isNotEmpty ? stores[0] : null);

            return SectionCard(
              title: 'Unidades do Grupo',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Empresa: ${tenant.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTokens.accentBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...stores.map(
                    (s) => Card(
                      color: s == currentStoreId
                          ? AppTokens.accentBlue.withAlpha(20)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: s == currentStoreId
                              ? AppTokens.accentBlue
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.store,
                          color: s == currentStoreId
                              ? AppTokens.accentBlue
                              : Colors.grey,
                        ),
                        title: Text(
                          s,
                          style: TextStyle(
                            fontWeight: s == currentStoreId
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: s == currentStoreId
                            ? const Text(
                                'Unidade Selecionada',
                                style: TextStyle(fontSize: 11),
                              )
                            : null,
                        onTap: () async {
                          if (s != currentStoreId) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user?.email?.trim().toLowerCase())
                                .update({'currentStoreId': s});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Unidade alterada para: $s'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  ...[
                    const Divider(height: 32),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Crie uma nova unidade para esta empresa.',
                        style: const TextStyle(
                          color: AppTokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddStoreDialog(tenant.id),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('CRIAR NOVA UNIDADE'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _showAddStoreDialog(String tenantId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Unidade'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome da Unidade (ex: Shopping)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ADICIONAR'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await ref
            .read(tenantRepositoryProvider)
            .addStoreToTenant(tenantId, result);
        final userEmail = ref
            .read(authViewModelProvider)
            .valueOrNull
            ?.email
            ?.trim()
            .toLowerCase();
        if (userEmail != null && userEmail.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userEmail)
              .update({'currentStoreId': result});
        }
        ref.invalidate(currentTenantProvider);
        ref.invalidate(userTenantsProvider);
        ref.invalidate(currentStoreIdProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unidade "$result" criada e selecionada.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      }
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? helper,
    void Function(String)? onChanged,
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
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperStyle: TextStyle(
              color: isDark ? Colors.white24 : Colors.black26,
              fontSize: 11,
            ),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: isDark ? AppTokens.vibrantCyan : AppTokens.electricBlue,
            ),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppTokens.electricBlue,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
