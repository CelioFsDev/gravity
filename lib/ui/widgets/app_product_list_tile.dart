import 'dart:io';
import 'dart:convert';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_card.dart';
import 'package:catalogo_ja/ui/widgets/app_badge_pill.dart';
import 'package:intl/intl.dart';

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

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTokens.space12),
      padding: const EdgeInsets.all(AppTokens.space12),
      onTap: onTap,
      onLongPress: onLongPress,
      decoration: isSelected
          ? BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            )
          : null,
      child: Row(
        children: [
          if (isSelected || onLongPress != null) ...[
            Checkbox(
              value: isSelected,
              onChanged: (_) => onTap(),
              shape: const CircleBorder(),
            ),
            const SizedBox(width: 8),
          ],
          // Thumbnail
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildImage(primaryImage?.uri),
          ),
          const SizedBox(width: AppTokens.space8),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppTokens.space8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      product.ref,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (product.promoEnabled)
                      const AppBadgePill(
                        label: 'PROMO',
                        color: AppTokens.accentRed,
                      ),
                    if (product.isOutOfStock)
                      const AppBadgePill(
                        label: 'ESGOTADO',
                        color: AppTokens.textMuted,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Varejo: ${currency.format(product.effectivePriceRetail)} • Atacado: ${currency.format(product.effectivePriceWholesale)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          if (trailing != null) ...[trailing!],
          if (trailing == null && onGoMainMenu != null)
            IconButton(
              tooltip: 'Menu principal',
              onPressed: onGoMainMenu,
              icon: const Icon(Icons.home_outlined),
            ),
          if (trailing == null && (onEdit != null || onDelete != null))
            _buildAdminMenu(context),
          if (trailing == null && onEdit == null && onDelete == null)
            const Icon(Icons.chevron_right),
        ],
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

  Widget _buildImage(String? path) {
    if (path == null) {
      return const Icon(Icons.image_not_supported);
    }

    if (path.startsWith('data:')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex != -1 && commaIndex + 1 < path.length) {
        try {
          return Image.memory(
            base64Decode(path.substring(commaIndex + 1)),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported),
          );
        } catch (_) {
          return const Icon(Icons.image_not_supported);
        }
      }
      return const Icon(Icons.image_not_supported);
    }

    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported),
      );
    }

    if (!kIsWeb) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported),
      );
    }

    return const Icon(Icons.image_not_supported);
  }

  ProductImage? _resolvePrimaryImage(Product product) {
    return product.mainImage;
  }
}
