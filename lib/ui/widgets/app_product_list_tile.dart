import 'dart:io';
import 'dart:convert';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:catalogo_ja/core/utils/uri_utils.dart';

class AppProductListTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onTogglePromo;
  final VoidCallback? onGoMainMenu;
  final Widget? trailing;
  final bool isSelected;
  final VoidCallback? onLongPress;

  const AppProductListTile({
    super.key,
    required this.product,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onTogglePromo,
    this.onGoMainMenu,
    this.trailing,
    this.isSelected = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final primaryImage = _resolvePrimaryImage(product);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isSelected
            ? AppTokens.electricBlue.withOpacity(0.1)
            : (isDark
                  ? Colors.white.withOpacity(0.03)
                  : Theme.of(context).cardColor),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? AppTokens.vibrantCyan.withOpacity(0.5)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Theme.of(context).dividerColor.withOpacity(0.1)),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          if (!isDark && !isSelected)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Stack(
        children: [
          if (primaryImage?.uri.trim().isNotEmpty == true)
            Positioned.fill(child: _buildCardWallpaper(primaryImage!.uri)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: isDark
                      ? [
                          AppTokens.cardDark.withOpacity(0.96),
                          AppTokens.cardDark.withOpacity(0.84),
                          AppTokens.cardDark.withOpacity(0.70),
                        ]
                      : [
                          Colors.white.withOpacity(0.96),
                          Colors.white.withOpacity(0.88),
                          Colors.white.withOpacity(0.74),
                        ],
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildPhotoFrame(context, primaryImage?.uri, isDark),
                  const SizedBox(width: 16),

                  // Info Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              product.ref,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (product.promoEnabled)
                              _buildMiniBadge('PROMO', AppTokens.vibrantPink),
                            if (product.isOutOfStock) const SizedBox(width: 4),
                            if (product.isOutOfStock)
                              _buildMiniBadge('OFF', Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildPriceTag(
                              context,
                              'VAREJO',
                              currency.format(product.effectivePriceRetail),
                              AppTokens.accentGreen,
                              isDark,
                            ),
                            const SizedBox(width: 12),
                            _buildPriceTag(
                              context,
                              'ATACADO',
                              currency.format(product.effectivePriceWholesale),
                              AppTokens.accentGreen,
                              isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  if (trailing != null) ...[trailing!],
                  if (trailing == null && onGoMainMenu != null)
                    IconButton(
                      onPressed: onGoMainMenu,
                      icon: Icon(
                        Icons.home_outlined,
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                    ),
                  if (trailing == null && (onEdit != null || onDelete != null))
                    _buildAdminMenu(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWallpaper(String originalPath) {
    final path = originalPath.trim();
    if (!UriUtils.isUsableImagePath(path)) return const SizedBox.shrink();

    if (path.startsWith('data:')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex != -1 && commaIndex + 1 < path.length) {
        try {
          return Image.memory(
            base64Decode(path.substring(commaIndex + 1)),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
        } catch (_) {
          return const SizedBox.shrink();
        }
      }
    }

    if (UriUtils.isNetworkImageUri(path)) {
      return CachedNetworkImage(
        imageUrl: path,
        cacheManager: DefaultCacheManager(),
        fit: BoxFit.cover,
        maxWidthDiskCache: 600,
        memCacheWidth: 360,
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      );
    }

    if (!kIsWeb) {
      try {
        final file = File(path);
        if (file.existsSync() &&
            file.statSync().type != FileSystemEntityType.directory) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: 360,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
        }
      } catch (_) {}
    }

    return const SizedBox.shrink();
  }

  Widget _buildMiniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPriceTag(
    BuildContext context,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoFrame(BuildContext context, String? imageUri, bool isDark) {
    return Container(
      width: 96,
      height: 96,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTokens.deepNavy.withOpacity(0.95),
                  AppTokens.electricBlue.withOpacity(0.26),
                  Colors.white.withOpacity(0.06),
                ]
              : [
                  const Color(0xFFF1F7FF),
                  const Color(0xFFEFFBF8),
                  const Color(0xFFFFF7ED),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppTokens.electricBlue.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.24)
                : AppTokens.electricBlue.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.16)
                : const Color(0xFFEAF3FF).withOpacity(0.58),
          ),
          child: _buildImage(imageUri),
        ),
      ),
    );
  }

  Widget _buildAdminMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') onDelete?.call();
        if (value == 'duplicate') onDuplicate?.call();
        if (value == 'togglePromo') onTogglePromo?.call();
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Editar'),
              ],
            ),
          ),
        if (onDuplicate != null)
          const PopupMenuItem(
            value: 'duplicate',
            child: Row(
              children: [
                Icon(Icons.copy_outlined, size: 18),
                SizedBox(width: 8),
                Text('Duplicar'),
              ],
            ),
          ),
        if (onTogglePromo != null)
          PopupMenuItem(
            value: 'togglePromo',
            child: Row(
              children: [
                const Icon(Icons.percent_outlined, size: 18),
                const SizedBox(width: 8),
                Text(product.promoEnabled ? 'Remover Promo' : 'Ativar Promo'),
              ],
            ),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppTokens.accentRed,
                ),
                SizedBox(width: 8),
                Text('Excluir', style: TextStyle(color: AppTokens.accentRed)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildImage(String? originalPath) {
    if (originalPath == null || originalPath.trim().isEmpty) {
      return const Icon(
        Icons.image_not_supported_outlined,
        size: 24,
        color: Colors.grey,
      );
    }

    final path = originalPath.trim();
    if (!UriUtils.isUsableImagePath(path)) {
      return const Icon(
        Icons.image_not_supported_outlined,
        size: 24,
        color: Colors.grey,
      );
    }

    // 1. Network / Cloud / Blob
    if (UriUtils.isNetworkImageUri(path)) {
      return CachedNetworkImage(
        imageUrl: path,
        cacheManager: DefaultCacheManager(),
        fit: BoxFit.contain,
        maxWidthDiskCache: 400,
        memCacheWidth: 200,
        placeholder: (context, url) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.broken_image_outlined,
          size: 20,
          color: AppTokens.textMuted,
        ),
      );
    }

    // 2. Data URI (Base64)
    if (path.startsWith('data:')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex != -1 && commaIndex + 1 < path.length) {
        try {
          return Image.memory(
            base64Decode(path.substring(commaIndex + 1)),
            fit: BoxFit.contain,
            cacheWidth: 200,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image_outlined, size: 20),
          );
        } catch (_) {}
      }
    }

    // 3. Local File (Non-Web)
    if (!kIsWeb) {
      try {
        final file = File(path);
        if (file.existsSync() &&
            file.statSync().type != FileSystemEntityType.directory) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            cacheWidth: 200,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image_outlined, size: 20),
          );
        }
      } catch (_) {}
    }

    // Final Fallback
    return const Icon(
      Icons.image_not_supported_outlined,
      size: 24,
      color: Colors.grey,
    );
  }

  ProductImage? _resolvePrimaryImage(Product product) {
    return product.mainImage;
  }
}
