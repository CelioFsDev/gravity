import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/services/catalog_share_helper.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:catalogo_ja/features/admin/catalogs/catalog_editor_screen.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:intl/intl.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart'; // Para SyncProgress

class CatalogsScreen extends ConsumerWidget {
  const CatalogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(catalogsViewModelProvider);
    final notifier = ref.read(catalogsViewModelProvider.notifier);
    final syncProgress = ref.watch(syncProgressProvider);
    final role = ref.watch(currentRoleProvider);

    return AppScaffold(
      title: 'Catálogos',
      subtitle: 'Gerencie seus catálogos digitais',
      actions: [
        if (role.canEditCatalog)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'add') _openNew(context);
              if (value == 'upload') _startCloudSync(context, notifier);
              if (value == 'download') _startCloudDownload(context, notifier);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add',
                child: Row(
                  children: [
                    Icon(Icons.add_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Novo Catálogo'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'upload',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Subir Catálogos (Nuvem)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.cloud_download_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Baixar Catálogos (Nuvem)'),
                  ],
                ),
              ),
            ],
          ),
      ],
      floatingActionButton: role.canEditCatalog
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateOptions(context),
              label: const Text('Novo Catálogo'),
              icon: const Icon(Icons.add),
              backgroundColor: AppTokens.accentBlue,
              foregroundColor: Colors.white,
            )
          : null,
      body: _CatalogsBackground(
        child: Column(
          children: [
            if (syncProgress.isSyncing)
              _buildSyncProgressBanner(context, syncProgress),
            Expanded(
              child: state.when(
                data: (catalogs) => _CatalogsContent(
                  catalogs: catalogs,
                  onCreate: role.canEditCatalog
                      ? () => _showCreateOptions(context)
                      : null,
                  onShare: (catalog) => CatalogShareHelper.showShareOptions(
                    context: context,
                    ref: ref,
                    catalog: catalog,
                  ),
                  onEdit: (catalog) => _openEdit(context, catalog),
                  onDelete: (catalog) => notifier.deleteCatalog(catalog.id),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => AppErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(catalogsViewModelProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.add_circle_outline,
                color: AppTokens.accentBlue,
              ),
              title: const Text('Novo Catálogo'),
              subtitle: const Text('Cria e salva na sua lista de catálogos'),
              onTap: () {
                Navigator.pop(context);
                _openNew(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.bolt_outlined,
                color: AppTokens.accentOrange,
              ),
              title: const Text('Catálogo Rápido'),
              subtitle: const Text(
                'Cria apenas para enviar PDF (sem salvar na lista)',
              ),
              onTap: () {
                Navigator.pop(context);
                _openNew(context, quick: true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openNew(BuildContext context, {bool quick = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CatalogEditorScreen(isQuick: quick)),
    );
  }

  void _openEdit(BuildContext context, Catalog catalog) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CatalogEditorScreen(catalog: catalog)),
    );
  }

  void _startCloudSync(BuildContext context, CatalogsViewModel notifier) async {
    try {
      await notifier.syncAllToCloud();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na sincronização: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startCloudDownload(
    BuildContext context,
    CatalogsViewModel notifier,
  ) async {
    try {
      await notifier.syncFromCloud();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar catálogos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSyncProgressBanner(BuildContext context, SyncProgress sync) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.95),
        border: const Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sync.message,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(sync.progress * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: sync.progress, minHeight: 4),
          ),
        ],
      ),
    );
  }
}

class _CatalogsBackground extends StatelessWidget {
  final Widget child;

  const _CatalogsBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppTokens.deepNavy, AppTokens.surfaceDark, AppTokens.deepNavy]
              : [
                  const Color(0xFFF0F7FF),
                  const Color(0xFFF7FBF9),
                  const Color(0xFFFFFAF3),
                ],
        ),
      ),
      child: child,
    );
  }
}

class _CatalogsContent extends ConsumerWidget {
  final List<Catalog> catalogs;
  final VoidCallback? onCreate;
  final ValueChanged<Catalog> onShare;
  final ValueChanged<Catalog> onEdit;
  final ValueChanged<Catalog> onDelete;

  const _CatalogsContent({
    required this.catalogs,
    required this.onCreate,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsViewModelProvider).valueOrNull;
    final productById = {
      for (final product in productsState?.allProducts ?? [])
        product.id: product,
    };

    if (catalogs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            AppEmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'Nenhum catálogo ainda',
              subtitle: 'Crie um catálogo para gerar PDF e compartilhar.',
              actionLabel: onCreate == null ? null : 'Criar catálogo',
              onAction: onCreate,
              message: '',
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space24,
        vertical: AppTokens.space12,
      ),
      itemCount: catalogs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final catalog = catalogs[index];
        final role = ref.watch(currentRoleProvider);
        final List<dynamic> backgroundImageUris = catalog.productIds
            .map((id) => productById[id]?.mainImage?.uri ?? '')
            .where((uri) => uri.trim().isNotEmpty)
            .take(4)
            .toList();

        return _EnhancedCatalogCard(
          catalog: catalog,
          onShare: () => onShare(catalog),
          onEdit: role.canEditCatalog ? () => onEdit(catalog) : null,
          onDelete: role.canEditCatalog ? () => onDelete(catalog) : null,
          backgroundImageUris: [
            backgroundImageUris.isNotEmpty ? backgroundImageUris[0] : '',
            backgroundImageUris.length > 1 ? backgroundImageUris[1] : '',
            backgroundImageUris.length > 2 ? backgroundImageUris[2] : '',
            backgroundImageUris.length > 3 ? backgroundImageUris[3] : '',
          ],
        );
      },
    );
  }
}

class CatalogCard extends StatelessWidget {
  final Catalog catalog;
  final VoidCallback onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CatalogCard({
    super.key,
    required this.catalog,
    required this.onShare,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy').format(catalog.updatedAt);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        title: Text(
          catalog.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildInfoChip(
                context,
                Icons.shopping_bag_outlined,
                '${catalog.productIds.length} produtos',
              ),
              _buildInfoChip(context, Icons.calendar_today_outlined, date),
              if (catalog.isPublic)
                _buildInfoChip(
                  context,
                  Icons.public,
                  'Público',
                  color: AppTokens.accentBlue,
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined, size: 20),
              tooltip: 'Compartilhar',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(width: 4),
              PopupMenuButton<_CatalogAction>(
                tooltip: 'Mais ações',
                onSelected: (value) {
                  switch (value) {
                    case _CatalogAction.share:
                      onShare();
                      break;
                    case _CatalogAction.edit:
                      onEdit?.call();
                      break;
                    case _CatalogAction.delete:
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: _CatalogAction.edit,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 12),
                          Text('Editar Detalhes'),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: _CatalogAction.delete,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppTokens.accentRed,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Excluir Catálogo',
                            style: TextStyle(color: AppTokens.accentRed),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: color != null ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }
}

class _EnhancedCatalogCard extends StatelessWidget {
  final Catalog catalog;
  final List<String> backgroundImageUris;
  final VoidCallback onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _EnhancedCatalogCard({
    required this.catalog,
    required this.backgroundImageUris,
    required this.onShare,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy').format(catalog.updatedAt);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark
            ? AppTokens.cardDark.withOpacity(0.88)
            : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppTokens.electricBlue.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.24)
                : AppTokens.electricBlue.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (backgroundImageUris.isNotEmpty)
            Positioned.fill(child: _buildWallpaper(context)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: isDark
                      ? [
                          AppTokens.cardDark.withOpacity(0.96),
                          AppTokens.cardDark.withOpacity(0.82),
                          AppTokens.cardDark.withOpacity(0.66),
                        ]
                      : [
                          Colors.white.withOpacity(0.96),
                          Colors.white.withOpacity(0.84),
                          Colors.white.withOpacity(0.68),
                        ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _buildCatalogMark(context),
                const SizedBox(width: 14),
                Expanded(child: _buildCatalogInfo(context, date)),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined, size: 20),
                  tooltip: 'Compartilhar',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (onEdit != null || onDelete != null) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<_CatalogAction>(
                    tooltip: 'Mais ações',
                    onSelected: (value) {
                      switch (value) {
                        case _CatalogAction.share:
                          onShare();
                          break;
                        case _CatalogAction.edit:
                          onEdit?.call();
                          break;
                        case _CatalogAction.delete:
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: _CatalogAction.edit,
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 12),
                              Text('Editar Detalhes'),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: _CatalogAction.delete,
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppTokens.accentRed,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Excluir Catálogo',
                                style: TextStyle(color: AppTokens.accentRed),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaper(BuildContext context) {
    final images = backgroundImageUris.take(4).toList();

    if (images.length == 1) {
      return _buildWallpaperImage(images.first);
    }

    return Row(
      children: images
          .map((uri) => Expanded(child: _buildWallpaperImage(uri)))
          .toList(),
    );
  }

  Widget _buildWallpaperImage(String uri) {
    final path = uri.trim();

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

    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }

    if (!kIsWeb) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
        }
      } catch (_) {}
    }

    return const SizedBox.shrink();
  }

  Widget _buildCatalogMark(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 58,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTokens.electricBlue.withOpacity(0.38),
                  AppTokens.vibrantCyan.withOpacity(0.16),
                ]
              : [
                  AppTokens.electricBlue.withOpacity(0.14),
                  AppTokens.accentGreen.withOpacity(0.12),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppTokens.electricBlue.withOpacity(0.14),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 12,
            right: 12,
            top: 13,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppTokens.electricBlue.withOpacity(isDark ? 0.7 : 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.menu_book_rounded,
              size: 28,
              color: isDark ? Colors.white : AppTokens.electricBlue,
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 13,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppTokens.accentGreen.withOpacity(isDark ? 0.65 : 0.48),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogInfo(BuildContext context, String date) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catálogo',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white54 : AppTokens.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          catalog.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _buildInfoChip(
              context,
              Icons.shopping_bag_outlined,
              '${catalog.productIds.length} produtos',
            ),
            _buildInfoChip(context, Icons.calendar_today_outlined, date),
            if (catalog.isPublic)
              _buildInfoChip(
                context,
                Icons.public,
                'Público',
                color: AppTokens.accentBlue,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: color != null ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }
}

enum _CatalogAction { share, edit, delete }
