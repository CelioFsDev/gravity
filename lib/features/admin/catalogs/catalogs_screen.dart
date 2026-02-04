import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/core/services/catalog_share_helper.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_scaffold.dart';
import 'package:gravity/ui/widgets/app_empty_state.dart';
import 'package:gravity/features/admin/catalogs/catalog_editor_screen.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/viewmodels/catalogs_viewmodel.dart';
import 'package:intl/intl.dart';

class CatalogsScreen extends ConsumerWidget {
  const CatalogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(catalogsViewModelProvider);
    final notifier = ref.read(catalogsViewModelProvider.notifier);

    return AppScaffold(
      title: 'Catálogos',
      subtitle: 'Gerencie seus catálogos digitais',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _openNew(context),
          tooltip: 'Novo Catálogo',
        ),
      ],
      body: state.when(
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
        error: (e, __) => Center(child: Text('Erro: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
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
}

class _CatalogsContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (catalogs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
        child: AppEmptyState(
          icon: Icons.collections_bookmark_outlined,
          title: 'Nenhum catálogo ainda',
          message: 'Crie um catálogo para gerar PDF e compartilhar.',
          actionLabel: 'Criar catálogo',
          onAction: onCreate,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space24,
        vertical: AppTokens.space12,
      ),
      itemCount: catalogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final catalog = catalogs[index];
        return CatalogCard(
          catalog: catalog,
          onShare: () => onShare(catalog),
          onEdit: () => onEdit(catalog),
          onDelete: () => onDelete(catalog),
        );
      },
    );
  }
}

class CatalogCard extends StatelessWidget {
  final Catalog catalog;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CatalogCard({
    super.key,
    required this.catalog,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          catalog.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 14),
              const SizedBox(width: 4),
              Text(
                '${catalog.productIds.length} produtos',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
              const Icon(Icons.calendar_today_outlined, size: 14),
              const SizedBox(width: 4),
              Text(date, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: PopupMenuButton<_CatalogAction>(
            tooltip: 'Ações',
            onSelected: (value) {
              switch (value) {
                case _CatalogAction.share:
                  onShare();
                  break;
                case _CatalogAction.edit:
                  onEdit();
                  break;
                case _CatalogAction.delete:
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _CatalogAction.share,
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Compartilhar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _CatalogAction.edit,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Editar'),
                  ],
                ),
              ),
              PopupMenuItem(
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
                      'Excluir',
                      style: TextStyle(color: AppTokens.accentRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CatalogAction { share, edit, delete }
