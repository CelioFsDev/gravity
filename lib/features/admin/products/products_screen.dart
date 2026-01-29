import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:gravity/features/admin/products/product_form_screen.dart';
import 'package:gravity/features/admin/products/product_import_screen.dart';
import 'package:gravity/features/admin/products/product_detail_screen.dart';
import 'package:gravity/core/services/product_transfer_service.dart';
import 'package:intl/intl.dart';
import 'package:gravity/core/widgets/responsive_scaffold.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productsViewModelProvider);

    return ResponsiveScaffold(
      body: state.when(
        data: (data) => _buildContent(context, ref, data),
        error: (e, s) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ProductsState state,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Produtos',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Catálogo de produtos',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProductFormScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Novo produto'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProductImportScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Importar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ProductTransferService.shareProductsPackage(
                          context,
                          ref,
                        ),
                    icon: const Icon(Icons.download),
                    label: const Text('Exportar'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              final itemWidth = isWide
                  ? (constraints.maxWidth - 48) / 4
                  : (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _buildKpiCard(
                      context,
                      'Total Produtos',
                      state.totalCount.toString(),
                      Colors.blue,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildKpiCard(
                      context,
                      'Ativos',
                      state.activeCount.toString(),
                      Colors.green,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildKpiCard(
                      context,
                      'Esgotados',
                      state.outOfStockCount.toString(),
                      Colors.red,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildKpiCard(
                      context,
                      'Em Promoção',
                      state.onSaleCount.toString(),
                      Colors.orange,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = constraints.maxWidth >= 600
                    ? 280.0
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nome, REF, cor...',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                        ),
                        onChanged: (val) => ref
                            .read(productsViewModelProvider.notifier)
                            .setSearchQuery(val),
                      ),
                    ),
                    DropdownButton<String>(
                      hint: const Text('Categoria'),
                      value: state.categoryFilterId,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todas Categorias'),
                        ),
                        ...state.categories.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (val) => ref
                          .read(productsViewModelProvider.notifier)
                          .setCategoryFilter(val),
                    ),
                    DropdownButton<ProductStatusFilter>(
                      value: state.statusFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: ProductStatusFilter.all,
                          child: Text('Todos Status'),
                        ),
                        DropdownMenuItem(
                          value: ProductStatusFilter.active,
                          child: Text('Ativo'),
                        ),
                        DropdownMenuItem(
                          value: ProductStatusFilter.outOfStock,
                          child: Text('Esgotado'),
                        ),
                        DropdownMenuItem(
                          value: ProductStatusFilter.inactive,
                          child: Text('Inativo'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(productsViewModelProvider.notifier)
                              .setStatusFilter(val);
                        }
                      },
                    ),
                    DropdownButton<ProductSort>(
                      value: state.sortOption,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: ProductSort.recent,
                          child: Text('Mais recentes'),
                        ),
                        DropdownMenuItem(
                          value: ProductSort.priceAsc,
                          child: Text('Menor Preço'),
                        ),
                        DropdownMenuItem(
                          value: ProductSort.priceDesc,
                          child: Text('Maior Preço'),
                        ),
                        DropdownMenuItem(
                          value: ProductSort.aToZ,
                          child: Text('A-Z'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(productsViewModelProvider.notifier)
                              .setSortOption(val);
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Grid
          if (state.filteredProducts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nenhum produto encontrado.'),
              ),
            ),

          LayoutBuilder(
            builder: (context, constraints) {
              final minCardWidth = 220;
              final crossAxisCount = math.max(
                1,
                (constraints.maxWidth ~/ minCardWidth),
              );
              final aspectRatio = crossAxisCount == 1 ? 1.1 : 0.75;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: aspectRatio,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: state.filteredProducts.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(
                    context,
                    ref,
                    state.filteredProducts[index],
                    state.categories,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    WidgetRef ref,
    Product product,
    List<Category> categories,
  ) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    final imagePath =
        (product.images.isNotEmpty &&
            product.mainImageIndex < product.images.length)
        ? product.images[product.mainImageIndex]
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              child: (imagePath != null && !kIsWeb)
                  ? Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_not_supported),
                    )
                  : const Icon(Icons.image, size: 48, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!product.isActive) _statusBadge('Inativo', Colors.grey),
                    if (product.isOutOfStock)
                      _statusBadge('Esgotado', Colors.red),
                    if (product.isOnSale) _statusBadge('Promo', Colors.orange),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'REF: ${product.reference}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currency.format(product.retailPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      currency.format(product.wholesalePrice),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(product: product),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductFormScreen(product: product),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        // Confirmation dialog?
                        ref
                            .read(productsViewModelProvider.notifier)
                            .deleteProduct(product.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
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
