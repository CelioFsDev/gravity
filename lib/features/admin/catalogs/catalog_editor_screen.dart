import 'package:gravity/core/services/catalog_share_helper.dart';
import 'package:gravity/data/repositories/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/viewmodels/catalog_editor_viewmodel.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:gravity/features/admin/catalogs/tabs/products_selection_tab.dart'; // Will create next

class CatalogEditorScreen extends ConsumerStatefulWidget {
  final Catalog? catalog;

  const CatalogEditorScreen({super.key, this.catalog});

  @override
  ConsumerState<CatalogEditorScreen> createState() => _CatalogEditorScreenState();
}

class _CatalogEditorScreenState extends ConsumerState<CatalogEditorScreen> with SingleTickerProviderStateMixin {
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
    // We use a ProviderScope override or family if needed, but here standard provider usage.
    // However, since we need distinct state for each editor instance (if multiple), 
    // usually autoDispose family is better. But simplest is just watch and we only have 1 editor at a time.
    // Ideally we reset state on init.
    // We'll trust the ViewModel handles init from argument. 
    // Actually Ref.watch(catalogEditorViewModelProvider(widget.catalog)) would work if family.
    // But we defined provider without family. Let's do a quick hack: use a dedicated provider or 
    // we just use the one we made and ensure we reset it? 
    // Let's modify the provider connection.
    
    // We need to initialize the ViewModel with the catalog.
    // This is tricky with plain riverpod generator unless family.
    // Let's rely on the fact that build(Catalog?) is defined.
    final state = ref.watch(catalogEditorViewModelProvider(widget.catalog?.id));
    final notifier = ref.read(catalogEditorViewModelProvider(widget.catalog?.id).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.catalog == null ? 'Novo Catálogo' : 'Editar Catálogo'),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.slugError!)),
                      );
                    }
                  },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Products
          // Needs access to all products to select
          Consumer(
            builder: (context, ref, _) {
               final productsState = ref.watch(productsViewModelProvider);
               return productsState.when(
                 data: (pData) => ProductsSelectionTab(
                   selectedIds: state.catalog.productIds,
                   onToggle: notifier.toggleProduct,
                   allProducts: pData.allProducts,
                   categories: pData.categories,
                 ),
                 error: (e,s) => Text('$e'),
                 loading: () => const Center(child: CircularProgressIndicator()),
               );
            },
          ),
          
          // Tab 2: Personalize
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Info
                TextFormField(
                  initialValue: state.catalog.name,
                  decoration: const InputDecoration(labelText: 'Nome do Catálogo', border: OutlineInputBorder()),
                  onChanged: notifier.updateName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: ValueKey(state.catalog.slug), // Rebuild if slug changes externally (normalization)
                  initialValue: state.catalog.slug,
                  decoration: InputDecoration(
                     labelText: 'URL (Slug)', 
                     prefixText: 'app.com/c/', 
                     border: const OutlineInputBorder(),
                     errorText: state.slugError,
                  ),
                  onChanged: notifier.updateSlug,
                ),
                 const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Catálogo Ativo'),
                  value: state.catalog.active,
                  onChanged: notifier.toggleActive,
                ),
                
                const Divider(height: 32),
                
                // Configs
                SwitchListTile(
                  title: const Text('Solicitar dados do cliente'),
                  subtitle: const Text('Exie nome/whatsapp ao abrir'),
                  value: state.catalog.requireCustomerData,
                  onChanged: notifier.setRequireCustomerData,
                ),
                
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Layout das fotos', border: OutlineInputBorder()),
                  initialValue: state.catalog.photoLayout,
                  items: const [
                    DropdownMenuItem(value: 'grid', child: Text('Grade (Padrão)')),
                    DropdownMenuItem(value: 'list', child: Text('Lista')),
                    DropdownMenuItem(value: 'carousel', child: Text('Carrossel')),
                  ],
                  onChanged: (v) => notifier.setPhotoLayout(v!),
                ),
                
                const Divider(height: 32),
                
                // Announcement
                SwitchListTile(
                  title: const Text('Barra de Anúncio'),
                  value: state.catalog.announcementEnabled,
                  onChanged: notifier.setAnnouncementEnabled,
                ),
                if (state.catalog.announcementEnabled)
                  TextFormField(
                    initialValue: state.catalog.announcementText,
                    decoration: const InputDecoration(labelText: 'Texto do anúncio', border: OutlineInputBorder()),
                    onChanged: notifier.setAnnouncementText,
                  ),

                 // Banners placeholder for now
                 const SizedBox(height: 24),
                 const Text('Banners Promocionais (Implementação futura de UI de upload)'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
