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
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for updates (e.g. if edited)
    final productsState = ref.watch(productsViewModelProvider);
    final currentStoreId = ref.watch(currentStoreIdProvider).valueOrNull;
    final updatedProduct =
        productsState.value?.allProducts.firstWhere(
          (p) => p.id == product.id,
          orElse: () => product,
        ) ??
        product;
    final categories = productsState.value?.categories ?? [];
    final categoryById = {for (final c in categories) c.id: c};

    final currency = NumberFormat.simpleCurrency(
      locale: Localizations.localeOf(context).toString(),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: updatedProduct.name,
      subtitle: 'REF: ${updatedProduct.ref}',
      useAppBar: false,
      actions: [
        IconButton(
          icon: Icon(
            Icons.edit_note_rounded,
            color: isDark ? AppTokens.vibrantCyan : AppTokens.electricBlue,
          ),
          onPressed: () {
            Navigator.of(context).push(
              AppMotion.pageRoute(
                child: ProductFormScreen(product: updatedProduct),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppTokens.accentRed,
          ),
          onPressed: () {
            ref
                .read(productsViewModelProvider.notifier)
                .deleteProduct(updatedProduct.id);
            Navigator.of(context).pop();
          },
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Images Carousel
            if (updatedProduct.images.isNotEmpty ||
                updatedProduct.photos.isNotEmpty)
              SizedBox(
                height: 340,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: updatedProduct.images.isNotEmpty
                      ? updatedProduct.images.length
                      : updatedProduct.photos.length,
                  itemBuilder: (context, index) {
                    final img = updatedProduct.images.isNotEmpty
                        ? updatedProduct.images[index]
                        : updatedProduct.photos[index].toProductImage();

                    return Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.05),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark ? 0.3 : 0.05,
                            ),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildDetailImage(context, img),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppTokens.surfaceDark : Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
              ),

            const SizedBox(height: 32),

            // Status Badges
            Wrap(
              spacing: 8,
              children: [
                if (!updatedProduct.getIsActive(currentStoreId))
                  AppBadgePill(label: 'Inativo', color: Colors.grey),
                if (updatedProduct.isOutOfStock)
                  AppBadgePill(label: 'Esgotado', color: AppTokens.accentRed),
                if (updatedProduct.promoEnabled)
                  AppBadgePill(
                    label: 'Em Promoção',
                    color: AppTokens.softOrange,
                  ),
              ],
            ),
            const SizedBox(height: 24),

            SectionCard(
              title: 'Informações Básicas',
              child: Column(
                children: [
                  _buildDetailRow(
                    context,
                    'SKU',
                    updatedProduct.sku.isEmpty ? '-' : updatedProduct.sku,
                    isDark,
                  ),
                  const Divider(height: 24),
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
                    isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SectionCard(
              title: 'Preços e Vendas',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildPriceBox(
                          context,
                          'Varejo',
                          currency.format(
                            PriceCalculator.effectiveRetail(
                              updatedProduct.getRetailPrice(currentStoreId),
                              updatedProduct.promoEnabled,
                              updatedProduct.promoPercent,
                            ),
                          ),
                          AppTokens.electricBlue,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPriceBox(
                          context,
                          'Atacado',
                          currency.format(
                            PriceCalculator.effectiveWholesale(
                              updatedProduct.getWholesalePrice(currentStoreId),
                              updatedProduct.promoEnabled,
                              updatedProduct.promoPercent,
                            ),
                          ),
                          AppTokens.softPurple,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoBox(
                    context,
                    'Mínimo para Atacado',
                    '${updatedProduct.minWholesaleQty} unidades',
                    Icons.shopping_bag_outlined,
                    isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SectionCard(
              title: 'Variantes',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TAMANHOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        updatedProduct.getAvailableSizes(currentStoreId).isEmpty
                        ? [
                            Text(
                              '-',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ]
                        : updatedProduct
                              .getAvailableSizes(currentStoreId)
                              .map(
                                (s) => _buildAttributeChip(context, s, isDark),
                              )
                              .toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'CORES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        updatedProduct
                            .getAvailableColors(currentStoreId)
                            .isEmpty
                        ? [
                            Text(
                              '-',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ]
                        : updatedProduct
                              .getAvailableColors(currentStoreId)
                              .map(
                                (c) => _buildAttributeChip(context, c, isDark),
                              )
                              .toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: Opacity(
                opacity: 0.5,
                child: Text(
                  'Atualizado em ${DateFormat('dd/MM/yyyy HH:mm').format(updatedProduct.updatedAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBox(
    BuildContext context,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.black45),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAttributeChip(BuildContext context, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildDetailImage(BuildContext context, ProductImage? image) {
    if (image == null || image.uri.trim().isEmpty) {
      return _buildErrorImage(
        context,
        icon: Icons.image_not_supported_outlined,
      );
    }

    final cleanUri = image.uri.trim();

    if (cleanUri.startsWith('data:')) {
      final commaIndex = cleanUri.indexOf(',');
      if (commaIndex != -1 && commaIndex + 1 < cleanUri.length) {
        try {
          return Image.memory(
            base64Decode(cleanUri.substring(commaIndex + 1)),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildErrorImage(context),
          );
        } catch (_) {}
      }
    }

    if (image.sourceType == ProductImageSource.networkUrl ||
        cleanUri.startsWith('http://') ||
        cleanUri.startsWith('https://') ||
        cleanUri.startsWith('gs://') ||
        cleanUri.startsWith('blob:')) {
      return Image.network(
        cleanUri,
        fit: BoxFit.cover,
        cacheWidth: 800,
        errorBuilder: (context, error, stackTrace) =>
            _buildErrorImage(context, uri: cleanUri),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          );
        },
      );
    }

    if (kIsWeb) {
      return _buildErrorImage(context, icon: Icons.web_asset_off_outlined);
    }

    return Image.file(
      File(cleanUri),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildErrorImage(context),
    );
  }

  Widget _buildErrorImage(
    BuildContext context, {
    IconData icon = Icons.broken_image_outlined,
    String? uri,
  }) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTokens.accentRed.withOpacity(0.5)),
          if (uri != null && kDebugMode)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Erro no link: $uri',
                style: const TextStyle(fontSize: 8, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
        ],
      ),
    );
  }
}
