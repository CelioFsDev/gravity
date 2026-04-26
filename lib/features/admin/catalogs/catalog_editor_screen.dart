import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/category.dart' show CategoryType;
import 'package:catalogo_ja/viewmodels/catalog_editor_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/features/admin/catalogs/tabs/products_selection_tab.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/core/services/catalog_share_helper.dart';

class CatalogEditorScreen extends ConsumerStatefulWidget {
  final Catalog? catalog;
  final bool isQuick;

  const CatalogEditorScreen({super.key, this.catalog, this.isQuick = false});
  static const defaultBaseUrl = 'https://CatalogoJa.app';

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
      title: widget.catalog == null
          ? 'Novo Cat\u00e1logo'
          : 'Editar Cat\u00e1logo',
      subtitle: 'Selecione produtos e personalize o cat\u00e1logo',
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
              Tab(text: 'Personaliza\u00e7\u00e3o'),
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
              : Icon(widget.isQuick ? Icons.send : Icons.check),
          onPressed: state.isSaving
              ? null
              : () async {
                  if (widget.isQuick) {
                    // Just share without saving to Firestore list
                    // (Actually the ViewModel might still save it to local state,
                    // but we won't persist it to the catalogs collection)
                    await CatalogShareHelper.showShareOptions(
                      context: context,
                      ref: ref,
                      catalog: state.catalog,
                    );
                  } else {
                    final success = await notifier.save();
                    if (success && context.mounted) {
                      Navigator.pop(context);
                    }
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
                  onSelectMany: notifier.selectProducts,
                  onDeselectMany: notifier.deselectProducts,
                  allProducts: pData.allProducts,
                  categories: pData.categories
                      .where(
                        (c) =>
                            c.type == CategoryType.productType ||
                            c.type == CategoryType.collection,
                      )
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
      bottomNavigationBar: Container(
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
            label: widget.isQuick ? 'GERAR E COMPARTILHAR' : 'SALVAR CATÁLOGO',
            icon: widget.isQuick ? Icons.send : Icons.check_circle_outline,
            onPressed: state.isSaving
                ? null
                : () async {
                    if (widget.isQuick) {
                      await CatalogShareHelper.showShareOptions(
                        context: context,
                        ref: ref,
                        catalog: state.catalog,
                      );
                    } else {
                      final success = await notifier.save();
                      if (success && context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
          ),
        ),
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
            title: 'Informa\u00e7\u00f5es B\u00e1sicas',
            child: Column(
              children: [
                _buildTextField(
                  label: 'Nome do Cat\u00e1logo',
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
            title: 'Configura\u00e7\u00f5es de Venda',
            child: Column(
              children: [
                _buildSwitchTile(
                  title: 'Cat\u00e1logo P\u00fablico',
                  subtitle: 'Dispon\u00edvel via link direto',
                  value: state.catalog.isPublic,
                  onChanged: notifier.setIsPublic,
                ),
                if (state.catalog.isPublic &&
                    state.catalog.shareCode.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'C\u00f3digo de Compartilhamento:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  state.catalog.shareCode,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: notifier.regenerateShareCode,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text(
                              'Trocar',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    'grid': 'Grade (Padr\u00e3o)',
                    'list': 'Lista Detalhada',
                    'carousel': 'Carrossel em Foco',
                  },
                  onChanged: (v) => notifier.setPhotoLayout(v!),
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Capa do PDF',
                  value:
                      state.catalog.coverType ??
                      (state.catalog.includeCover ? 'collection' : 'none'),
                  items: const {
                    'collection':
                        'Autom\u00e1tica (Baseada na cole\u00e7\u00e3o)',
                    'standard':
                        'Padr\u00e3o (Personaliza\u00e7\u00e3o apenas de texto)',
                    'none': 'Sem capa principal',
                  },
                  onChanged: (v) {
                    notifier.setCoverType(v);
                    // Legacy compatibility sync
                    notifier.setIncludeCover(v != 'none');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'An\u00fancios',
            child: Column(
              children: [
                _buildSwitchTile(
                  title: 'Barra de An\u00fancio Ativa',
                  value: state.catalog.announcementEnabled,
                  onChanged: notifier.setAnnouncementEnabled,
                ),
                if (state.catalog.announcementEnabled) ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: 'Texto do An\u00fancio',
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
      initialValue: value,
      onChanged: onChanged,
      isExpanded: true,
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
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(
                e.value,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
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
