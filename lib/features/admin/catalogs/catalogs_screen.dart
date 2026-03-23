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

    return AppScaffold(
      title: 'Catálogos',
      subtitle: 'Gerencie seus catálogos digitais',
      actions: [
        if (ref.watch(currentRoleProvider).canEditCatalog)
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
      body: Column(
        children: [
          if (syncProgress.isSyncing)
            _buildSyncProgressBanner(context, syncProgress),
          Expanded(
            child: state.when(
              data: (catalogs) => _CatalogsContent(
                catalogs: catalogs,
                onCreate: () => _openNew(context),
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
    );
  }

  void _openNew(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CatalogEditorScreen()));
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

  void _startCloudDownload(BuildContext context, CatalogsViewModel notifier) async {
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
            child: LinearProgressIndicator(
              value: sync.progress,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogsContent extends ConsumerWidget {
  final List<Catalog> catalogs;
  final VoidCallback onCreate;
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
    if (catalogs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            AppEmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'Nenhum catálogo ainda',
              message: 'Crie um catálogo para gerar PDF e compartilhar.',
              actionLabel: 'Criar catálogo',
              onAction: onCreate,
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
        return CatalogCard(
          catalog: catalog,
          onShare: () => onShare(catalog),
          onEdit: role.canEditCatalog ? () => onEdit(catalog) : null,
          onDelete: role.canEditCatalog ? () => onDelete(catalog) : null,
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

enum _CatalogAction { share, edit, delete }
