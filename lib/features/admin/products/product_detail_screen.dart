import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/features/admin/products/product_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:catalogo_ja/core/utils/price_calculator.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/ui/widgets/app_badge_pill.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for updates (e.g. if edited)
    final productsState = ref.watch(productsViewModelProvider);
    final updatedProduct =
        productsState.value?.allProducts.firstWhere(
          (p) => p.id == product.id,
          orElse: () => product,
        ) ??
        product;
    final categories = productsState.value?.categories ?? [];
    final categoryById = {for (final c in categories) c.id: c};

    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return AppScaffold(
      title: updatedProduct.name,
      subtitle: 'REF: ${updatedProduct.reference}',
      useAppBar: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductFormScreen(product: updatedProduct),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTokens.accentRed),
          onPressed: () {
            ref
                .read(productsViewModelProvider.notifier)
                .deleteProduct(updatedProduct.id);
            Navigator.of(context).pop();
          },
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTokens.space16),
            // Images Carousel / Main Image
            if (updatedProduct.images.isNotEmpty)
              SizedBox(
                height: 320,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: updatedProduct.images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            boxShadow: const [AppTokens.shadowSm],
                          ),
                          child: _buildDetailImage(
                            context,
                            updatedProduct.images[index],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: const Icon(Icons.image_not_supported_outlined, size: 64),
              ),

            const SizedBox(height: AppTokens.space24),

            // Header Info & Status
            Row(
              children: [
                if (!updatedProduct.isActive)
                  AppBadgePill(label: 'Inativo', color: Colors.grey),
                if (updatedProduct.isOutOfStock)
                  AppBadgePill(label: 'Esgotado', color: AppTokens.accentRed),
                if (updatedProduct.isOnSale)
                  AppBadgePill(
                    label: 'Em Promo\u00e7\u00e3o',
                    color: AppTokens.accentOrange,
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.space16),

            SectionCard(
              title: 'Informa\u00e7\u00f5es B\u00e1sicas',
              child: Column(
                children: [
                  _buildDetailRow(context, 'SKU', updatedProduct.sku),
                  _buildDetailRow(
                    context,
                    'Categorias',
                    updatedProduct.categoryIds
                        .map((id) => categoryById[id])
                        .where(
                          (c) =>
                              c != null && c.type == CategoryType.productType,
                        )
                        .map((c) => c!.safeName)
                        .join(', '),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTokens.space24),

            // Pricing
            SectionCard(
              title: 'Pre\u00e7os',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth >= 720
                      ? (constraints.maxWidth - 32) / 3
                      : constraints.maxWidth;
                  final retailEffective = PriceCalculator.effectiveRetail(
                    updatedProduct.retailPrice,
                    updatedProduct.isOnSale,
                    updatedProduct.saleDiscountPercent.toDouble(),
                  );
                  final wholesaleEffective = PriceCalculator.effectiveWholesale(
                    updatedProduct.wholesalePrice,
                    updatedProduct.isOnSale,
                    updatedProduct.saleDiscountPercent.toDouble(),
                  );
                  final cards = [
                    _buildPriceCard(
                      context,
                      'Varejo',
                      currency.format(updatedProduct.retailPrice),
                      currency.format(retailEffective),
                      updatedProduct.isOnSale,
                      Icons.person_outline,
                    ),
                    _buildPriceCard(
                      context,
                      'Atacado',
                      currency.format(updatedProduct.wholesalePrice),
                      currency.format(wholesaleEffective),
                      updatedProduct.isOnSale,
                      Icons.storefront_outlined,
                    ),
                    _buildInfoCard(
                      context,
                      'M\u00edn. Atacado',
                      '${updatedProduct.minWholesaleQty} un',
                      Icons.shopping_bag_outlined,
                    ),
                  ];
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: cards
                        .map((card) => SizedBox(width: cardWidth, child: card))
                        .toList(),
                  );
                },
              ),
            ),

            const SizedBox(height: AppTokens.space24),

            // Attributes
            SectionCard(
              title: 'Variantes e Atributos',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tamanhos Dispon\u00edveis',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: updatedProduct.sizes.isEmpty
                        ? [
                            const Text(
                              '-',
                              style: TextStyle(color: AppTokens.textMuted),
                            ),
                          ]
                        : updatedProduct.sizes
                              .map((s) => _buildAttributeChip(context, s))
                              .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cores Dispon\u00edveis',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: updatedProduct.colors.isEmpty
                        ? [
                            const Text(
                              '-',
                              style: TextStyle(color: AppTokens.textMuted),
                            ),
                          ]
                        : updatedProduct.colors
                              .map((c) => _buildAttributeChip(context, c))
                              .toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTokens.space32),
            Center(
              child: Text(
                'Criado em: ${DateFormat('dd/MM/yyyy HH:mm').format(updatedProduct.createdAt)}',
                style: const TextStyle(
                  color: AppTokens.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space48),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTokens.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(
    BuildContext context,
    String label,
    String baseValue,
    String effectiveValue,
    bool promoEnabled,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTokens.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!promoEnabled || effectiveValue == baseValue)
            Text(
              baseValue,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            )
          else ...[
            Text(
              baseValue,
              style: const TextStyle(
                color: AppTokens.textMuted,
                decoration: TextDecoration.lineThrough,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              effectiveValue,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTokens.accentOrange,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailImage(BuildContext context, ProductImage? image) {
    if (image == null || image.uri.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, size: 48),
      );
    }

    if (image.uri.startsWith('data:')) {
      final commaIndex = image.uri.indexOf(',');
      if (commaIndex != -1 && commaIndex + 1 < image.uri.length) {
        try {
          return Image.memory(
            base64Decode(image.uri.substring(commaIndex + 1)),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: AppTokens.accentRed,
              ),
            ),
          );
        } catch (_) {}
      }
    }

    if (image.sourceType == ProductImageSource.networkUrl ||
        image.uri.startsWith('http://') ||
        image.uri.startsWith('https://') ||
        image.uri.startsWith('blob:')) {
      return Image.network(
        image.uri,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: AppTokens.accentRed,
          ),
        ),
      );
    }

    if (kIsWeb) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 48,
          color: AppTokens.accentRed,
        ),
      );
    }

    return Image.file(
      File(image.uri),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          size: 48,
          color: AppTokens.accentRed,
        ),
      ),
    );
  }
}
