import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:gravity/features/admin/products/product_form_screen.dart';
import 'package:gravity/features/admin/products/product_detail_screen.dart';
import 'package:gravity/core/services/product_transfer_service.dart';
import 'package:gravity/features/admin/import/gravity_import_screen.dart';
import 'package:gravity/features/admin/import/nuvemshop_import_screen.dart';
import 'package:gravity/viewmodels/product_export_viewmodel.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/viewmodels/product_import_viewmodel.dart';
import 'package:gravity/ui/widgets/app_scaffold.dart';
import 'package:gravity/ui/widgets/app_kpi_card.dart';
import 'package:gravity/ui/widgets/app_search_field.dart';
import 'package:gravity/ui/widgets/app_empty_state.dart';
import 'package:gravity/ui/widgets/app_product_list_tile.dart';
import 'package:uuid/uuid.dart';

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
      subtitle: 'Gerencie seu catálogo de produtos',
      useAppBar: false,
      actions: [_buildMoreActions(context)],
      body: Column(
        children: [
          Expanded(
            child: state.when(
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
                onEditProduct: (product) => _openEdit(context, product),
                onDeleteProduct: (product) => _deleteProduct(product),
                onDuplicateProduct: (product) => _duplicateProduct(product),
                onTogglePromo: (product) => _togglePromo(product),
              ),
              error: (e, s) => AppEmptyState(
                icon: Icons.error_outline,
                title: 'Erro ao carregar',
                message: e.toString(),
                actionLabel: 'Tentar novamente',
                onAction: () =>
                    ref.read(productsViewModelProvider.notifier).refresh(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
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
        child: Row(
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
        ),
      ),
    );
  }

  Widget _buildMoreActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        if (value == 'export') _showExportOptions(context);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.share_outlined, size: 18),
              SizedBox(width: 8),
              Text('Exportar Catálogo'),
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
              title: const Text('Importar Backup (Gravity)'),
              subtitle: const Text(
                'Restaura produtos, categorias e coleções de um arquivo JSON.',
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GravityImportScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: const Text('Vincular Fotos p/ Referência'),
              subtitle: const Text(
                'Associa fotos automaticamente aos produtos puxando de uma pasta pela Referência.',
              ),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(productImportViewModelProvider.notifier)
                    .pickAndMatchImagesToExistingProducts()
                    .then((_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vinculação concluída com sucesso!'),
                          ),
                        );
                      }
                    });
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Sincronizar Fotos da Nuvem'),
              subtitle: const Text(
                'Baixa fotos automaticamente usando a URL Base configurada em Ajustes.',
              ),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(productImportViewModelProvider.notifier)
                    .syncRemoteImagesFromUrl()
                    .then((_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sincronização concluída com sucesso!',
                            ),
                          ),
                        );
                      }
                    });
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
                'Gera um arquivo .zip com todos os dados e imagens para migração.',
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
                ProductTransferService.shareGravityBackup(context, ref);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.file_present_outlined),
              title: const Text('Planilha para Edição (CSV)'),
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
      name: '${product.name} (Cópia)',
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
  final ValueChanged<Product> onEditProduct;
  final ValueChanged<Product> onDeleteProduct;
  final ValueChanged<Product> onDuplicateProduct;
  final ValueChanged<Product> onTogglePromo;

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
    required this.onEditProduct,
    required this.onDeleteProduct,
    required this.onDuplicateProduct,
    required this.onTogglePromo,
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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
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
        ),
        const SizedBox(height: AppTokens.space48),
      ],
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
              label: 'Promoções',
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
        return 'Inativo';
      case ProductStatusFilter.all:
        return 'Status';
    }
  }

  String _sortLabel(ProductSort sort) {
    switch (sort) {
      case ProductSort.recent:
        return 'Recentes';
      case ProductSort.priceAsc:
        return 'Menor preço';
      case ProductSort.priceDesc:
        return 'Maior preço';
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
  final ValueChanged<Product> onEditProduct;
  final ValueChanged<Product> onDeleteProduct;
  final ValueChanged<Product> onDuplicateProduct;
  final ValueChanged<Product> onTogglePromo;

  const _ProductsListSection({
    required this.state,
    required this.categories,
    required this.onNewProduct,
    required this.onViewProduct,
    required this.onEditProduct,
    required this.onDeleteProduct,
    required this.onDuplicateProduct,
    required this.onTogglePromo,
  });

  @override
  Widget build(BuildContext context) {
    if (state.filteredProducts.isEmpty) {
      return AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nenhum produto cadastrado',
        message: 'Adicione seu primeiro produto para montar o catálogo.',
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
          onTap: () => onViewProduct(product),
          onEdit: () => onEditProduct(product),
          onDelete: () => onDeleteProduct(product),
          onDuplicate: () => onDuplicateProduct(product),
          onTogglePromo: () => onTogglePromo(product),
        );
      },
    );
  }
}
