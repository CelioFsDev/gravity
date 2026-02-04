import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_card.dart';
import 'package:gravity/ui/widgets/app_badge_pill.dart';
import 'package:intl/intl.dart';

class AppProductCard extends StatelessWidget {
  final Product product;
  final CatalogMode mode;
  final VoidCallback onTap;

  const AppProductCard({
    super.key,
    required this.product,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final price = product.priceForMode(
      mode == CatalogMode.atacado ? 'atacado' : 'varejo',
    );
    final hasPromo = product.promoEnabled;
    final primaryImage = _resolvePrimaryImage(product);

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Area
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImage(primaryImage),
                if (hasPromo)
                  const Positioned(
                    top: AppTokens.space8,
                    left: AppTokens.space8,
                    child: AppBadgePill(
                      label: 'PROMO',
                      color: AppTokens.accentRed,
                    ),
                  ),
                if (product.isOutOfStock)
                  Container(
                    color: Colors.black.withOpacity(0.4),
                    alignment: Alignment.center,
                    child: const AppBadgePill(
                      label: 'ESGOTADO',
                      color: Colors.white,
                      isLarge: true,
                    ),
                  ),
              ],
            ),
          ),

          // Info Area
          Padding(
            padding: const EdgeInsets.all(AppTokens.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.ref,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTokens.space8),
                Text(
                  currency.format(price),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTokens.accentBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? path) {
    if (path == null) {
      return Container(
        color: AppTokens.bg,
        child: const Icon(
          Icons.image_not_supported,
          color: AppTokens.textMuted,
        ),
      );
    }

    final image = kIsWeb || path.startsWith('http')
        ? Image.network(path, fit: BoxFit.cover)
        : Image.file(File(path), fit: BoxFit.cover);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusMd),
      ),
      child: image,
    );
  }

  String? _resolvePrimaryImage(Product product) {
    if (product.images.isNotEmpty) {
      final idx = product.mainImageIndex;
      if (idx >= 0 && idx < product.images.length) return product.images[idx];
      return product.images.first;
    }
    return null;
  }
}
