import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:gravity/features/admin/products/product_form_screen.dart';
import 'package:gravity/features/admin/products/product_import_screen.dart';
import 'package:gravity/features/admin/products/product_detail_screen.dart';
import 'package:gravity/core/services/product_transfer_service.dart';
import 'package:intl/intl.dart';
import 'package:gravity/core/widgets/responsive_scaffold.dart';
import 'package:gravity/core/widgets/section_header.dart';
import 'package:gravity/core/widgets/kpi_card.dart';
import 'package:gravity/core/widgets/filter_chips_row.dart';
import 'package:gravity/core/widgets/filter_chip_button.dart';

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
          onImport: () => _openImport(context),
          onExport: () => _exportProducts(context),
          onViewProduct: (product) => _openDetails(context, product),
          onEditProduct: (product) => _openEdit(context, product),
          onDeleteProduct: (product) => _deleteProduct(product),
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
    notifier.setCategoryFilter(null);
    notifier.setStatusFilter(ProductStatusFilter.all);
    notifier.setSortOption(ProductSort.recent);
    _searchController.clear();
  }

  void _openNewProduct(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
  }

  void _openImport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductImportScreen()),
    );
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
  final VoidCallback onImport;
  final VoidCallback onExport;
  final ValueChanged<Product> onViewProduct;
  final ValueChanged<Product> onEditProduct;
  final ValueChanged<Product> onDeleteProduct;

  const _ProductsContent({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearFilters,
    required this.onSelectCategory,
    required this.onSelectStatus,
    required this.onSelectSort,
    required this.onNewProduct,
    required this.onImport,
    required this.onExport,
    required this.onViewProduct,
    required this.onEditProduct,
    required this.onDeleteProduct,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilters = state.searchQuery.isNotEmpty ||
        state.categoryFilterId != null ||
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
        return Theme(
          data: theme.copyWith(
            cardTheme: theme.cardTheme.copyWith(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          child: SingleChildScrollView(
            padding: padding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderSection(
                      isWide: isWide,
                      onNewProduct: onNewProduct,
                      onImport: onImport,
                      onExport: onExport,
                    ),
                    const SizedBox(height: 20),
                    _KpiSection(state: state),
                    const SizedBox(height: 20),
                    _SearchAndFiltersSection(
                      state: state,
                      controller: searchController,
                      onSearchChanged: onSearchChanged,
                      onClearFilters: hasFilters ? onClearFilters : null,
                      onSelectCategory: onSelectCategory,
                      onSelectStatus: onSelectStatus,
                      onSelectSort: onSelectSort,
                    ),
                    const SizedBox(height: 16),
                    _ProductsListSection(
                      state: state,
                      onNewProduct: onNewProduct,
                      onViewProduct: onViewProduct,
                      onEditProduct: onEditProduct,
                      onDeleteProduct: onDeleteProduct,
                    ),
                  ],
                ),
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
    return SectionHeader(
      title: 'Produtos',
      subtitle: 'Catalogo de produtos',
      primaryAction: SectionHeaderAction(
        label: 'Novo produto',
        icon: Icons.add,
        onPressed: onNewProduct,
      ),
      secondaryActions: [
        SectionHeaderAction(
          label: 'Importar',
          icon: Icons.file_upload,
          onPressed: onImport,
        ),
        SectionHeaderAction(
          label: 'Exportar',
          icon: Icons.file_download,
          onPressed: onExport,
        ),
      ],
      useMenuForSecondary: !isWide,
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
              child: KpiCard(
                title: 'Total',
                value: state.totalCount.toString(),
                icon: Icons.inventory_2_outlined,
                tone: Colors.blue,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: KpiCard(
                title: 'Ativos',
                value: state.activeCount.toString(),
                icon: Icons.check_circle_outline,
                tone: Colors.green,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: KpiCard(
                title: 'Esgotados',
                value: state.outOfStockCount.toString(),
                icon: Icons.remove_circle_outline,
                tone: Colors.red,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: KpiCard(
                title: 'Promocoes',
                value: state.onSaleCount.toString(),
                icon: Icons.local_offer_outlined,
                tone: Colors.orange,
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
        SizedBox(
          height: 48,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Buscar por nome, REF, cor...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(height: 12),
        FilterChipsRow(
          chips: [
            FilterChipButton(
              label: _categoryLabel(state),
              isActive: state.categoryFilterId != null,
              onPressed: () => _selectCategory(context),
            ),
            FilterChipButton(
              label: _statusLabel(state.statusFilter),
              isActive: state.statusFilter != ProductStatusFilter.all,
              onPressed: () => _selectStatus(context),
            ),
            FilterChipButton(
              label: _sortLabel(state.sortOption),
              isActive: state.sortOption != ProductSort.recent,
              onPressed: () => _selectSort(context),
            ),
          ],
          onClear: onClearFilters,
        ),
      ],
    );
  }

  String _categoryLabel(ProductsState state) {
    if (state.categoryFilterId == null) return 'Categoria: Todas';
    final category = state.categories
        .where((c) => c.id == state.categoryFilterId)
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
        return 'Ordenar: Menor preco';
      case ProductSort.priceDesc:
        return 'Ordenar: Maior preco';
      case ProductSort.aToZ:
        return 'Ordenar: A-Z';
    }
  }

  Future<void> _selectCategory(BuildContext context) async {
    final options = <_SheetOption<String?>>[
      const _SheetOption(value: null, label: 'Todas categorias'),
      ...state.categories.map((c) => _SheetOption(value: c.id, label: c.name)),
    ];
    final result = await _showSelectionSheet<String?>(
      context,
      title: 'Categoria',
      options: options,
      selected: state.categoryFilterId,
    );
    if (result != null || state.categoryFilterId != null) {
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
                    trailing:
                        isSelected ? const Icon(Icons.check) : const SizedBox(),
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
  final VoidCallback onNewProduct;
  final ValueChanged<Product> onViewProduct;
  final ValueChanged<Product> onEditProduct;
  final ValueChanged<Product> onDeleteProduct;

  const _ProductsListSection({
    required this.state,
    required this.onNewProduct,
    required this.onViewProduct,
    required this.onEditProduct,
    required this.onDeleteProduct,
  });

  @override
  Widget build(BuildContext context) {
    if (state.filteredProducts.isEmpty) {
      return _ProductsEmptyState(onNewProduct: onNewProduct);
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
          onView: () => onViewProduct(product),
          onEdit: () => onEditProduct(product),
          onDelete: () => onDeleteProduct(product),
        );
      },
    );
  }
}

class ProductListCard extends StatelessWidget {
  final Product product;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductListCard({
    super.key,
    required this.product,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final imagePath =
        (product.images.isNotEmpty && product.mainImageIndex < product.images.length)
            ? product.images[product.mainImageIndex]
            : null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductThumbnail(imagePath: imagePath),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'REF ${product.reference} • ${currency.format(product.retailPrice)} • ${product.isActive ? 'Ativo' : 'Inativo'}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (product.isOnSale)
                          _StatusBadge(text: 'Promo', color: Colors.orange),
                        if (product.isOutOfStock)
                          _StatusBadge(text: 'Esgotado', color: Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_ProductMenuAction>(
                tooltip: 'Acoes',
                onSelected: (value) {
                  if (value == _ProductMenuAction.view) {
                    onView();
                  } else if (value == _ProductMenuAction.edit) {
                    onEdit();
                  } else if (value == _ProductMenuAction.delete) {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ProductMenuAction.view,
                    child: Text('Ver detalhes'),
                  ),
                  PopupMenuItem(
                    value: _ProductMenuAction.edit,
                    child: Text('Editar'),
                  ),
                  PopupMenuItem(
                    value: _ProductMenuAction.delete,
                    child: Text('Excluir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ProductMenuAction { view, edit, delete }

class _ProductThumbnail extends StatelessWidget {
  final String? imagePath;

  const _ProductThumbnail({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        height: 72,
        color: Colors.grey.shade200,
        child: (imagePath != null && !kIsWeb)
            ? Image.file(
                File(imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(Icons.image_outlined, color: Colors.grey),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
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
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(
              6,
              (index) => Container(
                height: 96,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductsEmptyState extends StatelessWidget {
  final VoidCallback onNewProduct;

  const _ProductsEmptyState({required this.onNewProduct});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Nenhum produto cadastrado',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Adicione seu primeiro produto para montar o catalogo.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onNewProduct,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar produto'),
            ),
          ],
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
              Text(
                message,
                textAlign: TextAlign.center,
              ),
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

