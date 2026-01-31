import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/core/services/catalog_share_helper.dart';
import 'package:gravity/core/widgets/responsive_scaffold.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_section_header.dart';
import 'package:gravity/ui/widgets/app_primary_button.dart';
import 'package:gravity/ui/widgets/app_empty_state.dart';
import 'package:gravity/ui/widgets/app_card.dart';
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

    return ResponsiveScaffold(
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
        error: (e, __) => _CatalogsErrorState(
          message: 'Erro ao carregar catalogos: $e',
          onRetry: () => ref.invalidate(catalogsViewModelProvider),
        ),
        loading: () => const _CatalogsLoadingState(),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final padding = EdgeInsets.all(isWide ? 24 : 16);
        return SingleChildScrollView(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSectionHeader(
                    title: 'Catálogos',
                    subtitle: 'Gerencie seus catálogos digitais',
                    actions: [
                      AppPrimaryButton(
                        label: 'Novo',
                        icon: Icons.add,
                        onPressed: onCreate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (catalogs.isEmpty)
                    AppEmptyState(
                      icon: Icons.collections_bookmark_outlined,
                      title: 'Nenhum catálogo ainda',
                      message: 'Crie um catálogo para gerar PDF e compartilhar.',
                      actionLabel: 'Criar catálogo',
                      onAction: onCreate,
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: catalogs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final catalog = catalogs[index];
                        return CatalogCard(
                          catalog: catalog,
                          onShare: () => onShare(catalog),
                          onEdit: () => onEdit(catalog),
                          onDelete: () => onDelete(catalog),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
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

    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        title: Text(
          catalog.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${catalog.productIds.length} produtos • Atualizado em $date',
        ),
        trailing: PopupMenuButton<_CatalogAction>(
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
              child: Text('PDF / Compartilhar'),
            ),
            PopupMenuItem(value: _CatalogAction.edit, child: Text('Editar')),
            PopupMenuItem(value: _CatalogAction.delete, child: Text('Excluir')),
          ],
        ),
      ),
    );
  }
}

enum _CatalogAction { share, edit, delete }

class _CatalogsLoadingState extends StatelessWidget {
  const _CatalogsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(
              6,
              (index) => Container(
                height: 80,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTokens.border,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CatalogsErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


