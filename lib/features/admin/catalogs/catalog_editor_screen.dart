import 'package:gravity/core/widgets/responsive_scaffold.dart';
import 'package:gravity/core/services/catalog_share_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/category.dart' show CategoryType;
import 'package:gravity/viewmodels/catalog_editor_viewmodel.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:gravity/features/admin/catalogs/tabs/products_selection_tab.dart';
import 'package:flutter/services.dart';
import 'package:gravity/core/widgets/section_header.dart';

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

    return ResponsiveScaffold(
      maxWidth: 800,
      appBar: AppBar(
        title: Text(
          widget.catalog == null ? 'Novo Catálogo' : 'Editar Catálogo',
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Produtos'),
            Tab(text: 'Personalizar'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartilhar',
            onPressed: () async {
              if (!canShare) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selecione produtos para compartilhar'),
                  ),
                );
                return;
              }
              await CatalogShareHelper.showShareOptions(
                context: context,
                ref: ref,
                catalog: state.catalog,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: state.isSaving
                ? null
                : () async {
                    final success = await notifier.save();
                    if (success && context.mounted) {
                      Navigator.pop(context);
                    } else if (!success &&
                        state.slugError != null &&
                        context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(state.slugError!)));
                    }
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: SectionHeader(
              title: widget.catalog == null
                  ? 'Novo Catálogo'
                  : 'Editar Catálogo',
              subtitle: 'Selecione produtos e personalize o catálogo',
            ),
          ),
          Expanded(
            child: TabBarView(
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
                      error: (e, s) => Text('$e'),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: state.catalog.name,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Catálogo',
                        ),
                        onChanged: notifier.updateName,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: ValueKey(state.catalog.slug),
                        initialValue: state.catalog.slug,
                        decoration: InputDecoration(
                          labelText: 'URL (Slug)',
                          prefixText:
                              '${CatalogEditorScreen.defaultBaseUrl}/c/',
                          errorText: state.slugError,
                        ),
                        onChanged: notifier.updateSlug,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Modo do catálogo',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ToggleButtons(
                        isSelected: [
                          state.catalog.mode == CatalogMode.varejo,
                          state.catalog.mode == CatalogMode.atacado,
                        ],
                        onPressed: (index) {
                          final selected = index == 0
                              ? CatalogMode.varejo
                              : CatalogMode.atacado;
                          notifier.setMode(selected);
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        color: Theme.of(context).colorScheme.primary,
                        fillColor: Theme.of(context).colorScheme.primary,
                        constraints: const BoxConstraints(minHeight: 40),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Varejo'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Atacado'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Catálogo público'),
                        subtitle: const Text('Disponibiliza o link /c/...'),
                        value: state.catalog.isPublic,
                        onChanged: notifier.setIsPublic,
                      ),
                      if (state.catalog.isPublic)
                        state.catalog.shareCode.isNotEmpty
                            ? ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.link),
                                title: Text(
                                  '/c/${state.catalog.shareCode}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () async {
                                    final url =
                                        '${CatalogEditorScreen.defaultBaseUrl}/c/${state.catalog.shareCode}';
                                    await Clipboard.setData(
                                      ClipboardData(text: url),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Link copiado: $url'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              )
                            : const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Salve o catálago para gerar um link.',
                                ),
                              ),
                      TextButton(
                        onPressed: () => notifier.regenerateShareCode(),
                        child: const Text('Gerar novo código'),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Catálogo Ativo'),
                        value: state.catalog.active,
                        onChanged: notifier.toggleActive,
                      ),
                      const Divider(height: 32),
                      SwitchListTile(
                        title: const Text('Solicitar dados do cliente'),
                        subtitle: const Text('Exie nome/whatsapp ao abrir'),
                        value: state.catalog.requireCustomerData,
                        onChanged: notifier.setRequireCustomerData,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Layout das fotos',
                        ),
                        initialValue: state.catalog.photoLayout,
                        items: const [
                          DropdownMenuItem(
                            value: 'grid',
                            child: Text('Grade (Padrão)'),
                          ),
                          DropdownMenuItem(value: 'list', child: Text('Lista')),
                          DropdownMenuItem(
                            value: 'carousel',
                            child: Text('Carrossel'),
                          ),
                        ],
                        onChanged: (v) => notifier.setPhotoLayout(v!),
                      ),
                      const Divider(height: 32),
                      SwitchListTile(
                        title: const Text('Barra de Anúncio'),
                        value: state.catalog.announcementEnabled,
                        onChanged: notifier.setAnnouncementEnabled,
                      ),
                      if (state.catalog.announcementEnabled)
                        TextFormField(
                          initialValue: state.catalog.announcementText,
                          decoration: const InputDecoration(
                            labelText: 'Texto do anúncio',
                          ),
                          onChanged: notifier.setAnnouncementText,
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'Banners Promocionais (Implementação futura de UI de upload)',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



