import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_badge_pill.dart';
import 'package:catalogo_ja/ui/widgets/app_search_field.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesViewModelProvider);

    return AppScaffold(
      title: 'Cole\u00e7\u00f5es',
      subtitle: 'Gerencie suas cole\u00e7\u00f5es e cat\u00e1logos',
      actions: [
        FilledButton.icon(
          onPressed: () => context.push('/admin/collections/new'),
          icon: const Icon(Icons.add),
          label: const Text('Nova Cole\u00e7\u00e3o'),
        ),
      ],
      body: categoriesState.when(
        data: (state) {
          // Filter collections
          final collections = state.categories
              .where((c) => c.type == CategoryType.collection)
              .where(
                (c) =>
                    _searchQuery.isEmpty ||
                    c.safeName.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

          if (collections.isEmpty && _searchQuery.isEmpty) {
            return AppEmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'Nenhuma cole\u00e7\u00e3o',
              message:
                  'Crie sua primeira cole\u00e7\u00e3o para organizar seus produtos.',
              actionLabel: 'Criar Cole\u00e7\u00e3o',
              onAction: () => context.push('/admin/collections/new'),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space24,
                ),
                child: AppSearchField(
                  controller: _searchController,
                  hintText: 'Buscar cole\u00e7\u00f5es...',
                  onChanged: (value) => setState(() => _searchQuery = value),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              ),
              const SizedBox(height: AppTokens.space24),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.space24,
                    0,
                    AppTokens.space24,
                    AppTokens.space48,
                  ),
                  itemCount: collections.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    return _CollectionCard(
                      collection: collection,
                      onEdit: () => context.push(
                        '/admin/collections/${collection.id}/edit',
                      ),
                      onDelete: () => _confirmDelete(context, collection.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
        error: (e, s) => Center(child: Text('Erro: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Cole\u00e7\u00e3o?'),
        content: const Text(
          'Esta a\u00e7\u00e3o n\u00e3o pode ser desfeita. Os produtos vinculados perder\u00e3o esta associa\u00e7\u00e3o.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTokens.accentRed),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref
          .read(categoriesViewModelProvider.notifier)
          .deleteAndUncategorize(id);
    }
  }
}

class _CollectionCard extends StatelessWidget {
  final Category collection;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CollectionCard({
    required this.collection,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final coverPath = collection.cover?.coverMiniPath;
    final hasCover = coverPath != null && coverPath.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini Cover Preview (AspectRatio 1365/420 ~= 3.25)
            SizedBox(
              height: 120,
              width: double.infinity,
              child: hasCover
                  ? _buildCoverImage(coverPath, context)
                  : _buildPlaceholder(context),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                collection.safeName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!collection.isActive)
                              const AppBadgePill(
                                label: 'Inativo',
                                color: Colors.grey,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Slug: ${collection.slug}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTokens.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTokens.accentRed,
                    ),
                    tooltip: 'Excluir',
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Image.asset(
      'assets/branding/catalogs/catalogoja_catalogs_mini_1365x420.png',
      fit: BoxFit.cover,
      width: double.infinity,
    );
  }

  Widget _buildCoverImage(String coverPath, BuildContext context) {
    if (coverPath.startsWith('data:image') || coverPath.startsWith('http')) {
      return Image.network(
        coverPath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(context),
      );
    }

    return Image.file(
      File(coverPath),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _buildPlaceholder(context),
    );
  }
}
