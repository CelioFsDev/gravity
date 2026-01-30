import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/viewmodels/catalog_public_viewmodel.dart';
import 'package:intl/intl.dart';
import 'package:gravity/core/utils/price_calculator.dart';

class CatalogHomePage extends ConsumerStatefulWidget {
  final String shareCode;

  const CatalogHomePage({super.key, required this.shareCode});

  @override
  ConsumerState<CatalogHomePage> createState() => _CatalogHomePageState();
}

class _CatalogHomePageState extends ConsumerState<CatalogHomePage> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogPublicProvider(widget.shareCode));

    return catalogAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) =>
          Scaffold(body: Center(child: Text('Erro ao carregar catálogo: $e'))),
      data: (data) {
        if (data == null) {
          return const Scaffold(
            body: Center(child: Text('Catálogo não encontrado')),
          );
        }
        if (!data.catalog.active) {
          return const Scaffold(
            body: Center(child: Text('Catálogo indisponível')),
          );
        }

        final filteredProducts = _selectedCategoryId == null
            ? data.products
            : data.products
                  .where((p) => p.categoryIds.contains(_selectedCategoryId))
                  .toList();

        return Material(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(data.catalog.name),
                    centerTitle: true,
                  ),
                  body: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Chip(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          backgroundColor: Colors.blue.shade50,
                          label: Text(
                            data.catalog.mode.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      // Announcement
                      if (data.catalog.announcementEnabled &&
                          data.catalog.announcementText != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          color: Colors.amber.shade100,
                          child: Text(
                            data.catalog.announcementText!,
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Categories Chips
                      if (data.categories.isNotEmpty)
                        SizedBox(
                          height: 60,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            scrollDirection: Axis.horizontal,
                            itemCount: data.categories.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return ChoiceChip(
                                  label: const Text('Todos'),
                                  selected: _selectedCategoryId == null,
                                  onSelected: (v) => setState(
                                    () => _selectedCategoryId = null,
                                  ),
                                );
                              }
                              final cat = data.categories[index - 1];
                              return ChoiceChip(
                                label: Text(cat.name),
                                selected: _selectedCategoryId == cat.id,
                                onSelected: (v) => setState(
                                  () => _selectedCategoryId = v ? cat.id : null,
                                ),
                              );
                            },
                          ),
                        ),

                      // Products Grid/List
                      Expanded(
                        child: filteredProducts.isEmpty
                            ? const Center(
                                child: Text('Nenhum produto encontrado'),
                              )
                            : _buildProductLayout(
                                filteredProducts,
                                data.catalog.photoLayout,
                                data.catalog.mode,
                              ),
                      ),
                    ],
                  ),
                  // Floating Cart Button (optional, but requested)
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductLayout(
    List<Product> products,
    String layout,
    CatalogMode mode,
  ) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    if (layout == 'list') {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: _buildProductThumbnail(
                product.images.isNotEmpty ? product.images.first : null,
              ),
              title: Text(product.name),
              subtitle: Text('REF: ${product.reference}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [_buildPriceDisplay(currency, product, mode)],
              ),
              onTap: null,
            ),
          );
        },
      );
    }

    // Grid and Carousel (treated as Grid for now, real carousel needs different widget structure)
    // Prompt just said "photoLayout: grid, carousel, parallel".
    // Carousel usually means horizontal scroll or slider. Grid is vertical.
    // Parallel could be 1 column?
    // For now implementing Grid as safe default and Carousel layout as 1 column large image ("Instagram style").

    final isLarge =
        layout ==
        'carousel'; // mapping "carousel" to large cards 1 per row for vertical scroll
    // or maybe strict carousel? Let's assume vertical list of large cards.

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLarge ? 1 : 2,
        childAspectRatio: isLarge ? 1.5 : 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return GestureDetector(
          onTap: null,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildProductImageWidget(
                        product.images.isNotEmpty ? product.images.first : null,
                      ),
                      if (product.isOutOfStock)
                        Container(
                          color: Colors.black54,
                          alignment: Alignment.center,
                          child: const Text(
                            'ESGOTADO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      _buildPriceDisplay(currency, product, mode),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriceDisplay(
    NumberFormat currency,
    Product product,
    CatalogMode mode,
  ) {
    final base = mode == CatalogMode.atacado
        ? product.wholesalePrice
        : product.retailPrice;
    final effective = mode == CatalogMode.atacado
        ? PriceCalculator.effectiveWholesale(
            base,
            product.isOnSale,
            product.saleDiscountPercent.toDouble(),
          )
        : PriceCalculator.effectiveRetail(
            base,
            product.isOnSale,
            product.saleDiscountPercent.toDouble(),
          );
    final baseText = currency.format(base);
    final effectiveText = currency.format(effective);

    if (!product.isOnSale || effective >= base) {
      return Text(
        baseText,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          baseText,
          style: const TextStyle(
            decoration: TextDecoration.lineThrough,
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          effectiveText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildProductThumbnail(String? imagePath) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildProductImageWidget(imagePath),
    );
  }

  Widget _buildProductImageWidget(
    String? imagePath, {
    BoxFit fit = BoxFit.cover,
  }) {
    if (imagePath == null || kIsWeb) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported),
      );
    }

    return Image.file(
      File(imagePath),
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image),
      ),
    );
  }
}

