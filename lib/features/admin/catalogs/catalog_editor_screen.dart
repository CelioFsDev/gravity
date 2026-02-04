import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/category.dart' show CategoryType;
import 'package:gravity/viewmodels/catalog_editor_viewmodel.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:gravity/features/admin/catalogs/tabs/products_selection_tab.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_scaffold.dart';
import 'package:gravity/ui/widgets/section_card.dart';
import 'package:gravity/core/services/catalog_share_helper.dart';

class CatalogEditorScreen extends ConsumerStatefulWidget {
  final Catalog? catalog;

  const CatalogEditorScreen({super.key, this.catalog});
  static const defaultBaseUrl = 'https://gravity.app';

  @override
  ConsumerState<CatalogEditorScreen> createState() =>
      _CatalogEditorScreenState();
}

class _CatalogEditorScreenState extends ConsumerState<CatalogEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogEditorViewModelProvider(widget.catalog?.id));
    final notifier = ref.read(
      catalogEditorViewModelProvider(widget.catalog?.id).notifier,
    );
    final canShare = state.catalog.productIds.isNotEmpty;

    return AppScaffold(
      title: widget.catalog == null ? 'Novo Catálogo' : 'Editar Catálogo',
      subtitle: 'Selecione produtos e personalize o catálogo',
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTokens.border)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Selecione Produtos'),
              Tab(text: 'Personalização'),
            ],
          ),
        ),
      ),
      actions: [
        if (canShare)
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => CatalogShareHelper.showShareOptions(
              context: context,
              ref: ref,
              catalog: state.catalog,
            ),
          ),
        IconButton(
          icon: state.isSaving
              ? const CircularProgressIndicator(strokeWidth: 2)
              : const Icon(Icons.check),
          onPressed: state.isSaving
              ? null
              : () async {
                  final success = await notifier.save();
                  if (success && context.mounted) {
                    Navigator.pop(context);
                  }
                },
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final productsState = ref.watch(productsViewModelProvider);
              return productsState.when(
                data: (pData) => ProductsSelectionTab(
                  selectedIds: state.catalog.productIds,
                  onToggle: notifier.toggleProduct,
                  allProducts: pData.allProducts,
                  categories: pData.categories
                      .where((c) => c.type == CategoryType.productType)
                      .toList(),
                ),
                error: (e, s) => Center(child: Text('Erro: $e')),
                loading: () => const Center(child: CircularProgressIndicator()),
              );
            },
          ),
          _buildSettingsTab(state, notifier),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(
    CatalogEditorState state,
    CatalogEditorViewModel notifier,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: Column(
        children: [
          SectionCard(
            title: 'Informações Básicas',
            child: Column(
              children: [
                _buildTextField(
                  label: 'Nome do Catálogo',
                  initialValue: state.catalog.name,
                  onChanged: notifier.updateName,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'URL (Slug)',
                  initialValue: state.catalog.slug,
                  prefix: '${CatalogEditorScreen.defaultBaseUrl}/c/',
                  errorText: state.slugError,
                  onChanged: notifier.updateSlug,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Configurações de Venda',
            child: Column(
              children: [
                _buildSwitchTile(
                  title: 'Catálogo Público',
                  subtitle: 'Disponível via link direto',
                  value: state.catalog.isPublic,
                  onChanged: notifier.setIsPublic,
                ),
                _buildSwitchTile(
                  title: 'Exigir Dados do Cliente',
                  subtitle: 'Solicita Nome/WhatsApp ao abrir',
                  value: state.catalog.requireCustomerData,
                  onChanged: notifier.setRequireCustomerData,
                ),
                const SizedBox(height: 12),
                _buildModeToggle(state, notifier),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Visual e Layout',
            child: Column(
              children: [
                _buildDropdown(
                  label: 'Layout das fotos',
                  value: state.catalog.photoLayout,
                  items: const {
                    'grid': 'Grade (Padrão)',
                    'list': 'Lista Detalhada',
                    'carousel': 'Carrossel em Foco',
                  },
                  onChanged: (v) => notifier.setPhotoLayout(v!),
                ),
                _buildSwitchTile(
                  title: 'Incluir Capas no PDF',
                  value: state.catalog.includeCover,
                  onChanged: notifier.setIncludeCover,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Anúncios',
            child: Column(
              children: [
                _buildSwitchTile(
                  title: 'Barra de Anúncio Ativa',
                  value: state.catalog.announcementEnabled,
                  onChanged: notifier.setAnnouncementEnabled,
                ),
                if (state.catalog.announcementEnabled) ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: 'Texto do Anúncio',
                    initialValue: state.catalog.announcementText ?? '',
                    onChanged: notifier.setAnnouncementText,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    String? prefix,
    String? errorText,
  }) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        errorText: errorText,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 13))
          : null,
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      activeColor: AppTokens.accentBlue,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      items: items.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
    );
  }

  Widget _buildModeToggle(
    CatalogEditorState state,
    CatalogEditorViewModel notifier,
  ) {
    return Row(
      children: [
        const Text(
          'Modelo de Loja:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        ToggleButtons(
          isSelected: [
            state.catalog.mode == CatalogMode.varejo,
            state.catalog.mode == CatalogMode.atacado,
          ],
          onPressed: (index) => notifier.setMode(
            index == 0 ? CatalogMode.varejo : CatalogMode.atacado,
          ),
          borderRadius: BorderRadius.circular(8),
          constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
          fillColor: AppTokens.accentBlue,
          selectedColor: Colors.white,
          children: const [Text('Varejo'), Text('Atacado')],
        ),
      ],
    );
  }
}
