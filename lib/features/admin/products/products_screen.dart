import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/features/admin/products/product_form_screen.dart';
import 'package:catalogo_ja/features/admin/products/product_detail_screen.dart';
import 'package:catalogo_ja/core/services/product_transfer_service.dart';
import 'package:catalogo_ja/features/admin/import/catalogo_ja_import_screen.dart';
import 'package:catalogo_ja/features/admin/import/nuvemshop_import_screen.dart';
import 'package:catalogo_ja/viewmodels/product_export_viewmodel.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/viewmodels/product_import_viewmodel.dart';
import 'package:catalogo_ja/features/admin/products/product_bulk_edit_screen.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/app_kpi_card.dart';
import 'package:catalogo_ja/ui/widgets/app_search_field.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_product_list_tile.dart';
import 'package:uuid/uuid.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsViewModelProvider);

    return AppScaffold(
      title: 'Produtos',
      subtitle: 'Gerencie seu cat\u00e1logo de produtos',
      useAppBar: false,
      actions: [
        if (ref.watch(currentRoleProvider).canManageRegistrations)
          _buildMoreActions(context),
      ],
      body: Column(
        children: [
          _buildBulkActionsBar(context),
          Expanded(
            child: state.whenStandard(
              onRetry: () =>
                  ref.read(productsViewModelProvider.notifier).refresh(),
              data: (data) => _ProductsContent(
                state: data,
                searchController: _searchController,
                onSearchChanged: (value) => ref
                    .read(productsViewModelProvider.notifier)
                    .setSearchQuery(value),
                onClearFilters: () => _clearFilters(data),
                onSelectCategory: (value) => ref
                    .read(productsViewModelProvider.notifier)
                    .setCategoryFilter(value),
                onSelectStatus: (value) => ref
                    .read(productsViewModelProvider.notifier)
                    .setStatusFilter(value),
                onSelectSort: (value) => ref
                    .read(productsViewModelProvider.notifier)
                    .setSortOption(value),
                onNewProduct: () => _openNewProduct(context),
                onViewProduct: (product) => _openDetails(context, product),
                onEditProduct:
                    ref.watch(currentRoleProvider).canManageRegistrations
                    ? (product) => _openEdit(context, product)
                    : null,
                onDeleteProduct: ref.watch(currentRoleProvider).canDeleteProduct
                    ? (product) => _deleteProduct(product)
                    : null,
                onDuplicateProduct:
                    ref.watch(currentRoleProvider).canManageRegistrations
                    ? (product) => _duplicateProduct(product)
                    : null,
                onTogglePromo:
                    ref.watch(currentRoleProvider).canManageRegistrations
                    ? (product) => _togglePromo(product)
                    : null,
                onRefresh: () async =>
                    ref.read(productsViewModelProvider.notifier).refresh(),
                onToggleSelection: (id) => ref
                    .read(productsViewModelProvider.notifier)
                    .toggleSelection(id),
              ),
            ),
          ),
          state.maybeWhen(
            data: (data) => _buildBottomBar(context),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionsBar(BuildContext context) {
    final state = ref.watch(productsViewModelProvider).value;
    if (state == null || state.selectedProductIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = state.selectedProductIds.length;
    final notifier = ref.read(productsViewModelProvider.notifier);
    final role = ref.watch(currentRoleProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Text(
            '$count selecionados',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (role.canDeleteProduct)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmBulkDelete(context),
              tooltip: 'Excluir selecionados',
            ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            onPressed: () => _showBulkCategoryDialog(context),
            tooltip: 'Alterar categoria',
          ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => notifier.updateStatusSelected(true),
            tooltip: 'Ativar todos',
          ),
          IconButton(
            icon: const Icon(Icons.visibility_off_outlined),
            onPressed: () => notifier.updateStatusSelected(false),
            tooltip: 'Desativar todos',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => notifier.clearSelection(),
            tooltip: 'Limpar sele\u00e7\u00e3o',
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Selecionados'),
        content: const Text(
          'Deseja realmente excluir todos os itens selecionados? Esta a\u00e7\u00e3o n\u00e3o pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(productsViewModelProvider.notifier).deleteSelected();
              Navigator.pop(context);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBulkCategoryDialog(BuildContext context) {
    final state = ref.read(productsViewModelProvider).value;
    if (state == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar Categoria'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.categories.length,
            itemBuilder: (context, index) {
              final cat = state.categories[index];
              return ListTile(
                title: Text(cat.safeName),
                onTap: () {
                  final catId = cat.id;
                  ref
                      .read(productsViewModelProvider.notifier)
                      .updateCategorySelected(catId);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
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
        top: false,
        child: ref.watch(currentRoleProvider).canManageRegistrations
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openImport(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: const Text('Importar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openNewProduct(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Novo Produto'),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildMoreActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        if (value == 'export') _showExportOptions(context);
        if (value == 'bulk_edit') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProductBulkEditScreen()),
          );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'bulk_edit',
          child: Row(
            children: [
              Icon(Icons.edit_note_outlined, size: 18),
              SizedBox(width: 8),
              Text('Edi\u00e7\u00e3o R\u00e1pida (Pre\u00e7os)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.share_outlined, size: 18),
              SizedBox(width: 8),
              Text('Exportar Cat\u00e1logo'),
            ],
          ),
        ),
      ],
    );
  }

  void _clearFilters(ProductsState state) {
    // ... logic remains same
    final notifier = ref.read(productsViewModelProvider.notifier);
    notifier.setSearchQuery('');
    notifier.setCategoryFilter(null);
    notifier.setStatusFilter(ProductStatusFilter.all);
    notifier.setSortOption(ProductSort.recent);
    _searchController.clear();
  }

  void _openNewProduct(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProductFormScreen()));
  }

  void _openImport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Importar Backup (CatalogoJa)'),
              subtitle: const Text(
                'Restaura produtos, categorias e cole\u00e7\u00f5es de um arquivo JSON.',
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CatalogoJaImportScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: const Text('Vincular Fotos p/ Refer\u00eancia'),
              subtitle: const Text(
                'Associa fotos automaticamente aos produtos puxando de uma pasta pela Refer\u00eancia.',
              ),
              onTap: () {
                Navigator.pop(context);
                _startPhotoReferenceLinking();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Sincronizar Fotos da Nuvem'),
              subtitle: const Text(
                'Baixa fotos automaticamente usando a URL Base configurada em Ajustes.',
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                ref.read(productImportViewModelProvider.notifier).reset();
                await ref
                    .read(productImportViewModelProvider.notifier)
                    .syncRemoteImagesFromUrl();
                if (!mounted) return;

                final syncState = ref.read(productImportViewModelProvider);
                if (syncState.errorMessage != null) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(syncState.errorMessage!)),
                  );
                  return;
                }

                final matched = syncState.imagesMatchedCount;
                final total = syncState.imagesTotalCount;
                final message = matched > 0
                    ? 'Sincronização concluída: $matched produto(s) com foto em $total verificados.'
                    : 'Sincronização concluída sem fotos encontradas. Verifique a URL Base e os nomes (REF.ext).';
                messenger.showSnackBar(SnackBar(content: Text(message)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_fix_high_outlined),
              title: const Text('Reorganizar Fotos'),
              subtitle: const Text(
                'Aplica a regra da foto principal (P) para produtos antigos.',
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final updatedCount = await ref
                      .read(productsViewModelProvider.notifier)
                      .reorganizePhotosPriority();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        updatedCount > 0
                            ? 'Reorganização concluída em $updatedCount produto(s).'
                            : 'Nenhum produto precisou de reorganização.',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao reorganizar fotos: $e')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text('Sincronizar Planilha Nuvemshop'),
              subtitle: const Text(
                'Importa produtos e baixa fotos automaticamente do CSV Nuvemshop.',
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NuvemshopImportScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Backup Completo (com Fotos)'),
              subtitle: const Text(
                'Gera um arquivo .zip com todos os dados e imagens para migra\u00e7\u00e3o.',
              ),
              onTap: () {
                Navigator.pop(context);
                final viewModel = ref.read(
                  productExportViewModelProvider.notifier,
                );
                _showExportProgressDialog(context);

                viewModel
                    .exportPackage()
                    .then((_) {
                      if (context.mounted) Navigator.pop(context);
                    })
                    .catchError((e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                      }
                    });
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Backup Simples (Apenas Dados)'),
              subtitle: const Text('Arquivo JSON leve sem imagens.'),
              onTap: () {
                Navigator.pop(context);
                ProductTransferService.shareCatalogoJaBackup(context, ref);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.file_present_outlined),
              title: const Text('Planilha para Edi\u00e7\u00e3o (CSV)'),
              subtitle: const Text(
                'Exporta produtos e fotos em formato CSV/ZIP.',
              ),
              onTap: () {
                Navigator.pop(context);
                ProductTransferService.shareProductsPackage(context, ref);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _startPhotoReferenceLinking() {
    final screenContext = context;
    ref.read(productImportViewModelProvider.notifier).reset();
    _showVincularProgressDialog(screenContext);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref
            .read(productImportViewModelProvider.notifier)
            .pickAndMatchImagesToExistingProducts();

        if (!mounted) return;
        final stateAfter = ref.read(productImportViewModelProvider);
        final rootNav = Navigator.of(screenContext, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.pop();
        }

        if (stateAfter.errorMessage != null) {
          ScaffoldMessenger.of(
            screenContext,
          ).showSnackBar(SnackBar(content: Text(stateAfter.errorMessage!)));
          return;
        }

        final msg = stateAfter.imagesMatchedCount > 0
            ? 'Vincula\u00e7\u00e3o conclu\u00edda: ${stateAfter.imagesMatchedCount} fotos vinculadas.'
            : 'Vincula\u00e7\u00e3o conclu\u00edda sem correspond\u00eancias.';
        ScaffoldMessenger.of(
          screenContext,
        ).showSnackBar(SnackBar(content: Text(msg)));
      } catch (e) {
        if (!mounted) return;
        final rootNav = Navigator.of(screenContext, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.pop();
        }
        ScaffoldMessenger.of(
          screenContext,
        ).showSnackBar(SnackBar(content: Text('Erro ao vincular: $e')));
      }
    });
  }

  void _showVincularProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final importState = ref.watch(productImportViewModelProvider);
            final failures = importState.linkReport
                .where((item) => !item.linked)
                .toList();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              ),
              title: const Text('Vinculando Fotos'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: importState.progress,
                    backgroundColor: AppTokens.accentBlue.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTokens.accentBlue,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    importState.message ?? 'Iniciando...',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(importState.progress * 100).toInt()}%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (importState.imagesMatchedCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${importState.imagesMatchedCount} fotos vinculadas',
                      style: TextStyle(
                        color: importState.imagesMatchedCount > 0
                            ? AppTokens.accentGreen
                            : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (importState.isDone &&
                      importState.linkReport.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Relatório: ${importState.imagesMatchedCount}/${importState.imagesTotalCount} vinculadas',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (importState.isDone && failures.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Não vinculadas (${failures.length})',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 140,
                      width: 320,
                      child: ListView.separated(
                        itemCount: failures.length,
                        separatorBuilder: (_, _) => const Divider(height: 10),
                        itemBuilder: (context, index) {
                          final item = failures[index];
                          return Text(
                            '${item.fileName}: ${item.reason}',
                            style: const TextStyle(fontSize: 11),
                          );
                        },
                      ),
                    ),
                  ],
                  if (importState.errorMessage != null ||
                      (importState.isDone &&
                          importState.imagesMatchedCount == 0)) ...[
                    const SizedBox(height: 20),
                    if (importState.errorMessage != null)
                      Text(
                        importState.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      )
                    else
                      const Text(
                        'Nenhuma foto correspondeu \u00e0s refer\u00eancias dos produtos selecionados.',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
                  ],
                  if (!importState.isLoading &&
                      importState.errorMessage == null &&
                      !importState.isDone) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showExportProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final exportState = ref.watch(productExportViewModelProvider);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              ),
              title: const Text('Preparando Backup'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: exportState.progress,
                    backgroundColor: AppTokens.accentBlue.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTokens.accentBlue,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    exportState.message ?? 'Iniciando...',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(exportState.progress * 100).toInt()}%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openDetails(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  void _openEdit(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
  }

  void _deleteProduct(Product product) {
    ref.read(productsViewModelProvider.notifier).deleteProduct(product.id);
  }

  void _duplicateProduct(Product product) {
    final copy = product.copyWith(
      id: const Uuid().v4(),
      name: '${product.name} (C\u00f3pia)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    ref.read(productsViewModelProvider.notifier).addProduct(copy);
  }

  void _togglePromo(Product product) {
    final enabled = !product.promoEnabled;
    final percent = enabled && product.promoPercent <= 0
        ? 10.0
        : product.promoPercent;
    final updated = product.copyWith(
      promoEnabled: enabled,
      promoPercent: enabled ? percent : 0.0,
      updatedAt: DateTime.now(),
    );
    ref.read(productsViewModelProvider.notifier).updateProduct(updated);
  }
}

class _ProductsContent extends StatelessWidget {
  final ProductsState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearFilters;

  final ValueChanged<String?> onSelectCategory;
  final ValueChanged<ProductStatusFilter> onSelectStatus;
  final ValueChanged<ProductSort> onSelectSort;
  final VoidCallback onNewProduct;
  final ValueChanged<Product> onViewProduct;
  final ValueChanged<Product>? onEditProduct;
  final ValueChanged<Product>? onDeleteProduct;
  final ValueChanged<Product>? onDuplicateProduct;
  final ValueChanged<Product>? onTogglePromo;
  final RefreshCallback onRefresh;
  final ValueChanged<String> onToggleSelection;

  const _ProductsContent({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearFilters,

    required this.onSelectCategory,
    required this.onSelectStatus,
    required this.onSelectSort,
    required this.onNewProduct,
    required this.onViewProduct,
    this.onEditProduct,
    this.onDeleteProduct,
    this.onDuplicateProduct,
    this.onTogglePromo,
    required this.onRefresh,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        state.searchQuery.isNotEmpty ||
        state.productTypeFilterId != null ||
        state.statusFilter != ProductStatusFilter.all ||
        state.sortOption != ProductSort.recent;

    if (searchController.text != state.searchQuery) {
      searchController.value = TextEditingValue(
        text: state.searchQuery,
        selection: TextSelection.collapsed(offset: state.searchQuery.length),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: 20,
      color: AppTokens.accentBlue,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
        physics:
            const AlwaysScrollableScrollPhysics(), // Important for Pull-to-Refresh
        children: [
          const SizedBox(height: AppTokens.space16),
          _KpiSection(state: state),
          const SizedBox(height: AppTokens.space24),
          _SearchAndFiltersSection(
            state: state,
            controller: searchController,
            onSearchChanged: onSearchChanged,
            onClearFilters: hasFilters ? onClearFilters : null,

            onSelectCategory: onSelectCategory,
            onSelectStatus: onSelectStatus,
            onSelectSort: onSelectSort,
          ),
          const SizedBox(height: AppTokens.space24),
          _ProductsListSection(
            state: state,
            categories: state.categories,
            onNewProduct: onNewProduct,
            onViewProduct: onViewProduct,
            onEditProduct: onEditProduct,
            onDeleteProduct: onDeleteProduct,
            onDuplicateProduct: onDuplicateProduct,
            onTogglePromo: onTogglePromo,
            selectedIds: state.selectedProductIds,
            onToggleSelection: onToggleSelection,
          ),
          const SizedBox(height: AppTokens.space48),
        ],
      ),
    );
  }
}

class _KpiSection extends StatelessWidget {
  final ProductsState state;
  const _KpiSection({required this.state});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 88,
      ),
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return AppKpiCard(
              label: 'Total',
              value: state.totalCount.toString(),
              color: AppTokens.accentBlue,
              icon: Icons.inventory_2_outlined,
            );
          case 1:
            return AppKpiCard(
              label: 'Ativos',
              value: state.activeCount.toString(),
              color: AppTokens.accentGreen,
              icon: Icons.check_circle_outline,
            );
          case 2:
            return AppKpiCard(
              label: 'Esgotados',
              value: state.outOfStockCount.toString(),
              color: AppTokens.accentRed,
              icon: Icons.error_outline,
            );
          case 3:
            return AppKpiCard(
              label: 'Promo\u00e7\u00f5es',
              value: state.onSaleCount.toString(),
              color: AppTokens.accentOrange,
              icon: Icons.percent_rounded,
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

class _SearchAndFiltersSection extends StatelessWidget {
  final ProductsState state;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onClearFilters;

  final ValueChanged<String?> onSelectCategory;
  final ValueChanged<ProductStatusFilter> onSelectStatus;
  final ValueChanged<ProductSort> onSelectSort;

  const _SearchAndFiltersSection({
    required this.state,
    required this.controller,
    required this.onSearchChanged,
    required this.onClearFilters,

    required this.onSelectCategory,
    required this.onSelectStatus,
    required this.onSelectSort,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchField(
          controller: controller,
          hintText: 'Buscar por nome, REF, cor...',
          onChanged: onSearchChanged,
          onClear: onClearFilters,
        ),
        const SizedBox(height: AppTokens.space12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              const SizedBox(width: 8),
              _FilterChip(
                label: _categoryLabel(state),
                isActive: state.productTypeFilterId != null,
                onPressed: () => _selectCategory(context),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: _statusLabel(state.statusFilter),
                isActive: state.statusFilter != ProductStatusFilter.all,
                onPressed: () => _selectStatus(context),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: _sortLabel(state.sortOption),
                isActive: state.sortOption != ProductSort.recent,
                onPressed: () => _selectSort(context),
              ),
              if (onClearFilters != null) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Limpar',
                  isActive: false,
                  onPressed: onClearFilters,
                  isDestructive: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _categoryLabel(ProductsState state) {
    if (state.productTypeFilterId == null) return 'Categoria';
    final category = state.categories
        .where((c) => c.id == state.productTypeFilterId)
        .map((c) => c.name)
        .firstOrNull;
    return category ?? 'Categoria';
  }

  String _statusLabel(ProductStatusFilter status) {
    switch (status) {
      case ProductStatusFilter.active:
        return 'Ativo';
      case ProductStatusFilter.outOfStock:
        return 'Esgotado';
      case ProductStatusFilter.inactive:
        return 'Inativos';
      case ProductStatusFilter.withPhotos:
        return 'Com Fotos';
      case ProductStatusFilter.noPhotos:
        return 'Sem Fotos';
      case ProductStatusFilter.zeroPrice:
        return 'Pre\u00e7o Zero';
      case ProductStatusFilter.createdToday:
        return 'Criados Hoje';
      case ProductStatusFilter.all:
        return 'Todos os Status';
    }
  }

  String _sortLabel(ProductSort sort) {
    switch (sort) {
      case ProductSort.recent:
        return 'Recentes';
      case ProductSort.priceAsc:
        return 'Menor pre\u00e7o';
      case ProductSort.priceDesc:
        return 'Maior pre\u00e7o';
      case ProductSort.aToZ:
        return 'A-Z';
    }
  }

  Future<void> _selectCategory(BuildContext context) async {
    final categories = state.categories
        .where((c) => c.type == CategoryType.productType)
        .toList();
    final options = <_SheetOption<String?>>[
      const _SheetOption(value: null, label: 'Todas categorias'),
      ...categories.map((c) => _SheetOption(value: c.id, label: c.safeName)),
    ];
    final result = await _showSelectionSheet<String?>(
      context,
      title: 'Categoria',
      options: options,
      selected: state.productTypeFilterId,
    );
    if (result != null || state.productTypeFilterId != null) {
      onSelectCategory(result);
    }
  }

  Future<void> _selectStatus(BuildContext context) async {
    final options = const [
      _SheetOption(value: ProductStatusFilter.all, label: 'Todos'),
      _SheetOption(value: ProductStatusFilter.active, label: 'Ativo'),
      _SheetOption(value: ProductStatusFilter.outOfStock, label: 'Esgotado'),
      _SheetOption(value: ProductStatusFilter.inactive, label: 'Inativo'),
      _SheetOption(value: ProductStatusFilter.withPhotos, label: 'Com Fotos'),
      _SheetOption(value: ProductStatusFilter.noPhotos, label: 'Sem Fotos'),
    ];
    final result = await _showSelectionSheet<ProductStatusFilter>(
      context,
      title: 'Status',
      options: options,
      selected: state.statusFilter,
    );
    if (result != null) onSelectStatus(result);
  }

  Future<void> _selectSort(BuildContext context) async {
    final options = const [
      _SheetOption(value: ProductSort.recent, label: 'Mais recentes'),
      _SheetOption(value: ProductSort.priceAsc, label: 'Menor preco'),
      _SheetOption(value: ProductSort.priceDesc, label: 'Maior preco'),
      _SheetOption(value: ProductSort.aToZ, label: 'A-Z'),
    ];
    final result = await _showSelectionSheet<ProductSort>(
      context,
      title: 'Ordenar por',
      options: options,
      selected: state.sortOption,
    );
    if (result != null) onSelectSort(result);
  }

  Future<T?> _showSelectionSheet<T>(
    BuildContext context, {
    required String title,
    required List<_SheetOption<T>> options,
    required T? selected,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option.value == selected;
                  return ListTile(
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppTokens.accentBlue,
                          )
                        : null,
                    onTap: () => Navigator.pop(sheetContext, option.value),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const _FilterChip({
    required this.label,
    required this.isActive,
    this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: onPressed != null ? (_) => onPressed!() : null,
      backgroundColor: isDestructive
          ? AppTokens.accentRed.withOpacity(0.05)
          : null,
      selectedColor: AppTokens.accentBlue,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
        color: isActive
            ? Colors.white
            : (isDestructive
                  ? AppTokens.accentRed
                  : Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(
          color: isActive
              ? AppTokens.accentBlue
              : (isDestructive
                    ? AppTokens.accentRed.withOpacity(0.2)
                    : Theme.of(context).dividerColor),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    );
  }
}

class _SheetOption<T> {
  final T value;
  final String label;
  const _SheetOption({required this.value, required this.label});
}

class _ProductsListSection extends StatelessWidget {
  final ProductsState state;
  final List<Category> categories;
  final VoidCallback onNewProduct;
  final ValueChanged<Product> onViewProduct;
  final ValueChanged<Product>? onEditProduct;
  final ValueChanged<Product>? onDeleteProduct;
  final ValueChanged<Product>? onDuplicateProduct;
  final ValueChanged<Product>? onTogglePromo;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelection;

  const _ProductsListSection({
    required this.state,
    required this.categories,
    required this.onNewProduct,
    required this.onViewProduct,
    this.onEditProduct,
    this.onDeleteProduct,
    this.onDuplicateProduct,
    this.onTogglePromo,
    required this.selectedIds,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    if (state.filteredProducts.isEmpty) {
      return AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nenhum produto cadastrado',
        message: 'Adicione seu primeiro produto para montar o cat\u00e1logo.',
        actionLabel: 'Adicionar produto',
        onAction: onNewProduct,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.filteredProducts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = state.filteredProducts[index];
        return AppProductListTile(
          product: product,
          isSelected: selectedIds.contains(product.id),
          onLongPress: () => onToggleSelection(product.id),
          onTap: () {
            if (selectedIds.isNotEmpty) {
              onToggleSelection(product.id);
            } else {
              onViewProduct(product);
            }
          },
          onEdit: onEditProduct != null ? () => onEditProduct!(product) : null,
          onDelete: onDeleteProduct != null
              ? () => onDeleteProduct!(product)
              : null,
          onDuplicate: onDuplicateProduct != null
              ? () => onDuplicateProduct!(product)
              : null,
          onTogglePromo: onTogglePromo != null
              ? () => onTogglePromo!(product)
              : null,
        );
      },
    );
  }
}
