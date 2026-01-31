import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:gravity/features/admin/products/product_form_screen.dart';
import 'package:gravity/features/admin/products/product_import_screen.dart';
import 'package:gravity/features/admin/products/product_detail_screen.dart';
import 'package:gravity/core/services/product_transfer_service.dart';
import 'package:intl/intl.dart';
import 'package:gravity/core/widgets/responsive_scaffold.dart';
import 'package:gravity/core/utils/price_calculator.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_section_header.dart';
import 'package:gravity/ui/widgets/app_kpi_card.dart';
import 'package:gravity/ui/widgets/app_search_field.dart';
import 'package:gravity/ui/widgets/app_chip.dart';
import 'package:gravity/ui/widgets/app_primary_button.dart';
import 'package:gravity/ui/widgets/app_empty_state.dart';
import 'package:gravity/ui/widgets/app_card.dart';
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

    return ResponsiveScaffold(
      body: state.when(
        data: (data) => _ProductsContent(
          state: data,
          searchController: _searchController,
          onSearchChanged: (value) => ref
              .read(productsViewModelProvider.notifier)
              .setSearchQuery(value),
          onClearFilters: () => _clearFilters(data),
          onSelectCollection: (value) => ref
              .read(productsViewModelProvider.notifier)
              .setCollectionFilter(value),
          onSelectCategory: (value) => ref
              .read(productsViewModelProvider.notifier)
              .setCategoryFilter(value),
          onSelectStatus: (value) => ref
              .read(productsViewModelProvider.notifier)
              .setStatusFilter(value),
          onSelectSort: (value) =>
              ref.read(productsViewModelProvider.notifier).setSortOption(value),
          onNewProduct: () => _openNewProduct(context),
          onImport: () => _openImport(context),
          onExport: () => _exportProducts(context),
          onViewProduct: (product) => _openDetails(context, product),
          onEditProduct: (product) => _openEdit(context, product),
          onDeleteProduct: (product) => _deleteProduct(product),
          onDuplicateProduct: (product) => _duplicateProduct(product),
          onTogglePromo: (product) => _togglePromo(product),
        ),
        error: (e, s) => _ProductsErrorState(
          message: 'Erro ao carregar produtos: $e',
          onRetry: () => ref.read(productsViewModelProvider.notifier).refresh(),
        ),
        loading: () => const _ProductsLoadingState(),
      ),
    );
  }

  void _clearFilters(ProductsState state) {
    final notifier = ref.read(productsViewModelProvider.notifier);
    notifier.setSearchQuery('');
    notifier.setCollectionFilter(null);
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProductImportScreen()));
  }

  void _exportProducts(BuildContext context) {
    ProductTransferService.shareProductsPackage(context, ref);
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
    final percent =
        enabled && product.promoPercent <= 0 ? 10.0 : product.promoPercent;
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
  final ValueChanged<String?> onSelectCollection;
  final ValueChanged<String?> onSelectCategory;
  final ValueChanged<ProductStatusFilter> onSelectStatus;
  final ValueChanged<ProductSort> onSelectSort;
  final VoidCallback onNewProduct;
  final VoidCallback onImport;
  final VoidCallback onExport;
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
    required this.onSelectCollection,
    required this.onSelectCategory,
    required this.onSelectStatus,
    required this.onSelectSort,
    required this.onNewProduct,
    required this.onImport,
    required this.onExport,
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
        state.collectionFilterId != null ||
        state.productTypeFilterId != null ||
        state.statusFilter != ProductStatusFilter.all ||
        state.sortOption != ProductSort.recent;

    if (searchController.text != state.searchQuery) {
      searchController.value = TextEditingValue(
        text: state.searchQuery,
        selection: TextSelection.collapsed(offset: state.searchQuery.length),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final padding = EdgeInsets.all(isWide ? 24 : 16);
        return SingleChildScrollView(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderSection(
                    isWide: isWide,
                    onNewProduct: onNewProduct,
                    onImport: onImport,
                    onExport: onExport,
                  ),
                  const SizedBox(height: AppTokens.space24),
                  _KpiSection(state: state),
                  const SizedBox(height: AppTokens.space24),
                  _SearchAndFiltersSection(
                    state: state,
                    controller: searchController,
                    onSearchChanged: onSearchChanged,
                    onClearFilters: hasFilters ? onClearFilters : null,
                    onSelectCollection: onSelectCollection,
                    onSelectCategory: onSelectCategory,
                    onSelectStatus: onSelectStatus,
                    onSelectSort: onSelectSort,
                  ),
                  const SizedBox(height: AppTokens.space16),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final bool isWide;
  final VoidCallback onNewProduct;
  final VoidCallback onImport;
  final VoidCallback onExport;

  const _HeaderSection({
    required this.isWide,
    required this.onNewProduct,
    required this.onImport,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(
      title: 'Produtos',
      subtitle: 'Catálogo de produtos',
      actions: [
        OutlinedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.file_upload, size: 18),
          label: const Text('Importar'),
        ),
        AppPrimaryButton(
          label: 'Novo',
          icon: Icons.add,
          onPressed: onNewProduct,
        ),
        PopupMenuButton<String>(
          tooltip: 'Mais ações',
          onSelected: (value) {
            if (value == 'export') onExport();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'export', child: Text('Exportar')),
          ],
          child: Container(
            padding: const EdgeInsets.all(AppTokens.space8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              border: Border.all(color: AppTokens.border),
            ),
            child: const Icon(Icons.more_horiz, size: 20),
          ),
        ),
      ],
    );
  }
}

class _KpiSection extends StatelessWidget {
  final ProductsState state;

  const _KpiSection({required this.state});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final columns = isWide ? 4 : 2;
        final itemWidth =
            (constraints.maxWidth - (12 * (columns - 1))) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: AppKpiCard(
                label: 'Total',
                value: state.totalCount.toString(),
                color: AppTokens.accentBlue,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: AppKpiCard(
                label: 'Ativos',
                value: state.activeCount.toString(),
                color: AppTokens.accentGreen,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: AppKpiCard(
                label: 'Esgotados',
                value: state.outOfStockCount.toString(),
                color: AppTokens.accentRed,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: AppKpiCard(
                label: 'Promoções',
                value: state.onSaleCount.toString(),
                color: Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchAndFiltersSection extends StatelessWidget {
  final ProductsState state;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onClearFilters;
  final ValueChanged<String?> onSelectCollection;
  final ValueChanged<String?> onSelectCategory;
  final ValueChanged<ProductStatusFilter> onSelectStatus;
  final ValueChanged<ProductSort> onSelectSort;

  const _SearchAndFiltersSection({
    required this.state,
    required this.controller,
    required this.onSearchChanged,
    required this.onClearFilters,
    required this.onSelectCollection,
    required this.onSelectCategory,
    required this.onSelectStatus,
    required this.onSelectSort,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSearchField(
            controller: controller,
            hintText: 'Buscar por nome, REF, cor...',
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: AppTokens.space12),
          Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space8,
            children: [
              AppChip(
                label: _collectionLabel(state),
                isActive: state.collectionFilterId != null,
                onPressed: () => _selectCollection(context),
              ),
              AppChip(
                label: _categoryLabel(state),
                isActive: state.productTypeFilterId != null,
                onPressed: () => _selectCategory(context),
              ),
              AppChip(
                label: _statusLabel(state.statusFilter),
                isActive: state.statusFilter != ProductStatusFilter.all,
                onPressed: () => _selectStatus(context),
              ),
              AppChip(
                label: _sortLabel(state.sortOption),
                isActive: state.sortOption != ProductSort.recent,
                onPressed: () => _selectSort(context),
              ),
              if (onClearFilters != null)
                AppChip(
                  label: 'Limpar filtros',
                  isActive: true,
                  onPressed: onClearFilters,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _collectionLabel(ProductsState state) {
    if (state.collectionFilterId == null) return 'Coleção: Todas';
    final collection = state.categories
        .where(
          (c) =>
              c.id == state.collectionFilterId &&
              c.type == CategoryType.collection,
        )
        .map((c) => c.name)
        .toList();
    if (collection.isEmpty) return 'Coleção: Todas';
    return 'Coleção: ${collection.first}';
  }

  String _categoryLabel(ProductsState state) {
    if (state.productTypeFilterId == null) return 'Categoria: Todas';
    final category = state.categories
        .where(
          (c) =>
              c.id == state.productTypeFilterId &&
              c.type == CategoryType.productType,
        )
        .map((c) => c.name)
        .toList();
    if (category.isEmpty) return 'Categoria: Todas';
    return 'Categoria: ${category.first}';
  }

  String _statusLabel(ProductStatusFilter status) {
    switch (status) {
      case ProductStatusFilter.active:
        return 'Status: Ativo';
      case ProductStatusFilter.outOfStock:
        return 'Status: Esgotado';
      case ProductStatusFilter.inactive:
        return 'Status: Inativo';
      case ProductStatusFilter.all:
        return 'Status: Todos';
    }
  }

  String _sortLabel(ProductSort sort) {
    switch (sort) {
      case ProductSort.recent:
        return 'Ordenar: Recentes';
      case ProductSort.priceAsc:
        return 'Ordenar: Menor preço';
      case ProductSort.priceDesc:
        return 'Ordenar: Maior preço';
      case ProductSort.aToZ:
        return 'Ordenar: A-Z';
    }
  }

  Future<void> _selectCategory(BuildContext context) async {
    final categories = state.categories
        .where((c) => c.type == CategoryType.productType)
        .toList();
    final options = <_SheetOption<String?>>[
      const _SheetOption(value: null, label: 'Todas categorias'),
      ...categories.map((c) => _SheetOption(value: c.id, label: c.name)),
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

  Future<void> _selectCollection(BuildContext context) async {
    final collections = state.categories
        .where((c) => c.type == CategoryType.collection)
        .toList();
    final options = <_SheetOption<String?>>[
      const _SheetOption(value: null, label: 'Todas coleções'),
      ...collections.map((c) => _SheetOption(value: c.id, label: c.name)),
    ];
    final result = await _showSelectionSheet<String?>(
      context,
      title: 'Coleção',
      options: options,
      selected: state.collectionFilterId,
    );
    if (result != null || state.collectionFilterId != null) {
      onSelectCollection(result);
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
    if (result != null) {
      onSelectStatus(result);
    }
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
    if (result != null) {
      onSelectSort(result);
    }
  }

  Future<T?> _showSelectionSheet<T>(
    BuildContext context, {
    required String title,
    required List<_SheetOption<T>> options,
    required T? selected,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option.value == selected;
                  return ListTile(
                    title: Text(option.label),
                    trailing: isSelected
                        ? const Icon(Icons.check)
                        : const SizedBox(),
                    onTap: () => Navigator.pop(sheetContext, option.value),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = state.filteredProducts[index];
        return ProductListCard(
          product: product,
          categories: categories,
          onView: () => onViewProduct(product),
          onEdit: () => onEditProduct(product),
          onDelete: () => onDeleteProduct(product),
          onDuplicate: () => onDuplicateProduct(product),
          onTogglePromo: () => onTogglePromo(product),
        );
      },
    );
  }
}

class ProductListCard extends StatelessWidget {
  final Product product;
  final List<Category> categories;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onTogglePromo;

  const ProductListCard({
    super.key,
    required this.product,
    required this.categories,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    required this.onTogglePromo,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final imagePath =
        (product.images.isNotEmpty &&
                product.mainImageIndex < product.images.length)
            ? product.images[product.mainImageIndex]
            : null;
    final categoryById = {for (final c in categories) c.id: c};
    final collectionName = product.categoryIds
        .map((id) => categoryById[id])
        .where((c) => c != null && c!.type == CategoryType.collection)
        .map((c) => c!.name)
        .toList();
    final typeNames = product.categoryIds
        .map((id) => categoryById[id])
        .where((c) => c != null && c!.type == CategoryType.productType)
        .map((c) => c!.name)
        .toList();
    final collectionLabel = collectionName.isNotEmpty
        ? collectionName.first
        : '-';
    final typeLabel = typeNames.isNotEmpty ? typeNames.join(', ') : '-';

    final retailEffective = PriceCalculator.effectiveRetail(
      product.retailPrice,
      product.isOnSale,
      product.saleDiscountPercent.toDouble(),
    );
    final wholesaleEffective = PriceCalculator.effectiveWholesale(
      product.wholesalePrice,
      product.isOnSale,
      product.saleDiscountPercent.toDouble(),
    );

    return AppCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      onTap: onView,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductThumbnail(imagePath: imagePath),
          const SizedBox(width: AppTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.space4),
                Text(
                  'REF: ${product.reference}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTokens.space8),
                Text(
                  currency.format(retailEffective),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTokens.accentGreen,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppTokens.space4),
                Text(
                  'Atacado: ${currency.format(wholesaleEffective)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTokens.space8),
                Text(
                  'Coleção: $collectionLabel • $typeLabel',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTokens.space8),
                Wrap(
                  spacing: AppTokens.space8,
                  runSpacing: AppTokens.space4,
                  children: [
                    _StatusPill(
                      label: product.isActive ? 'Ativo' : 'Inativo',
                      color: product.isActive
                          ? AppTokens.accentBlue
                          : AppTokens.textMuted,
                    ),
                    if (product.isOnSale)
                      const _StatusPill(
                        label: 'Promo',
                        color: Colors.orange,
                      ),
                    if (product.isOutOfStock)
                      const _StatusPill(
                        label: 'Esgotado',
                        color: AppTokens.accentRed,
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<_ProductMenuAction>(
            tooltip: 'Ações',
            onSelected: (value) {
              switch (value) {
                case _ProductMenuAction.edit:
                  onEdit();
                  break;
                case _ProductMenuAction.duplicate:
                  onDuplicate();
                  break;
                case _ProductMenuAction.togglePromo:
                  onTogglePromo();
                  break;
                case _ProductMenuAction.delete:
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _ProductMenuAction.edit,
                child: Text('Editar'),
              ),
              const PopupMenuItem(
                value: _ProductMenuAction.duplicate,
                child: Text('Duplicar'),
              ),
              PopupMenuItem(
                value: _ProductMenuAction.togglePromo,
                child: Text(
                  product.isOnSale ? 'Remover promo' : 'Marcar promo',
                ),
              ),
              const PopupMenuItem(
                value: _ProductMenuAction.delete,
                child: Text('Excluir'),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(AppTokens.space8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                border: Border.all(color: AppTokens.border),
              ),
              child: const Icon(Icons.more_horiz, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ProductMenuAction { edit, duplicate, togglePromo, delete }

class _ProductThumbnail extends StatelessWidget {
  final String? imagePath;

  const _ProductThumbnail({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Container(
        width: 64,
        height: 64,
        color: AppTokens.border,
        child: (imagePath != null && !kIsWeb)
            ? Image.file(
                File(imagePath!),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return const Center(child: Icon(Icons.image_outlined, color: Colors.grey));
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProductsLoadingState extends StatelessWidget {
  const _ProductsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(
              6,
              (index) => Container(
                height: 96,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTokens.border,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProductsErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

