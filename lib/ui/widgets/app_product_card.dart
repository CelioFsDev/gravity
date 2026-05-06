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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Area
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: _buildImage(mainImg),
                  ),
                  if (hasPromo)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _buildTag('PROMO', const Color(0xFFF43F5E)),
                    ),
                  if (product.isOutOfStock)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _buildTag('ESGOTADO', Colors.white, isLarge: true),
                    ),
                ],
              ),
            ),

            // Info Area
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.ref.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currency.format(price),
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
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

  Widget _buildTag(String label, Color color, {bool isLarge = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 12 : 8,
        vertical: isLarge ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == Colors.white ? Colors.black : Colors.white,
          fontSize: isLarge ? 12 : 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildImage(ProductImage? img) {
    if (img == null || img.uri.isEmpty) {
      return _buildPlaceholder();
    }

    final String uri = img.uri;

    // Check for gs:// or other unsupported schemes on web
    if (uri.startsWith('gs://')) {
      // Ideally we should resolve this, but for now show placeholder to avoid crash or empty
      return _buildPlaceholder(icon: Icons.cloud_off);
    }

    if (uri.startsWith('data:')) {
      return _buildDataUrlImage(uri);
    }

    if (uri.startsWith('http') || uri.startsWith('blob:')) {
      return CachedNetworkImage(
        imageUrl: uri,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }

    if (!kIsWeb) {
      final file = File(uri);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder({IconData icon = Icons.image_outlined}) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Icon(icon, color: const Color(0xFFCBD5E1), size: 32),
      ),
    );
  }

  Widget _buildDataUrlImage(String uri) {
    try {
      final commaIndex = uri.indexOf(',');
      if (commaIndex == -1) return _buildPlaceholder();
      final bytes = base64Decode(uri.substring(commaIndex + 1));
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {
      return _buildPlaceholder();
    }
  }
}
