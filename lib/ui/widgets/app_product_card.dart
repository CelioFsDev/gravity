import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_card.dart';
import 'package:catalogo_ja/ui/widgets/app_badge_pill.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter_svg/flutter_svg.dart';

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
    final mainImg = product.mainImage;

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
                _buildImage(mainImg),
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

  Widget _buildImage(ProductImage? img) {
    if (img == null || img.uri.isEmpty) {
      return SvgPicture.asset(
        'assets/branding/placeholders/catalogoja_placeholder_produto_1024x1024.svg',
        fit: BoxFit.cover,
      );
    }

    final Widget imageWidget;
    final isDataUrl = img.uri.startsWith('data:');
    final isRemote =
        img.sourceType == ProductImageSource.networkUrl ||
        img.uri.startsWith('http://') ||
        img.uri.startsWith('https://') ||
        img.uri.startsWith('blob:');

    if (isDataUrl) {
      imageWidget = _buildDataUrlImage(img.uri);
    } else if (isRemote) {
      imageWidget = CachedNetworkImage(
        imageUrl: img.uri,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppTokens.bg,
          padding: const EdgeInsets.all(AppTokens.space24),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => SvgPicture.asset(
          'assets/branding/placeholders/catalogoja_placeholder_produto_1024x1024.svg',
          fit: BoxFit.cover,
        ),
      );
    } else if (img.sourceType == ProductImageSource.localPath && !kIsWeb) {
      imageWidget = Image.file(
        File(img.uri),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => SvgPicture.asset(
          'assets/branding/placeholders/catalogoja_placeholder_produto_1024x1024.svg',
          fit: BoxFit.cover,
        ),
      );
    } else {
      imageWidget = SvgPicture.asset(
        'assets/branding/placeholders/catalogoja_placeholder_produto_1024x1024.svg',
        fit: BoxFit.cover,
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusMd),
      ),
      child: imageWidget,
    );
  }

  Widget _buildDataUrlImage(String uri) {
    final commaIndex = uri.indexOf(',');
    if (commaIndex == -1 || commaIndex + 1 >= uri.length) {
      return SvgPicture.asset(
        'assets/branding/placeholders/catalogoja_placeholder_produto_1024x1024.svg',
        fit: BoxFit.cover,
      );
    }

    try {
      final bytes = base64Decode(uri.substring(commaIndex + 1));
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => SvgPicture.asset(
          'assets/branding/placeholders/catalogoja_placeholder_produto_1024x1024.svg',
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {
      return SvgPicture.asset(
        'assets/branding/placeholders/catalogoja_placeholder_produto_1024x1024.svg',
        fit: BoxFit.cover,
      );
    }
  }
}
