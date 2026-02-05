import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_scaffold.dart';
import 'package:gravity/ui/widgets/app_empty_state.dart';
import 'package:gravity/ui/widgets/app_badge_pill.dart';
import 'package:gravity/ui/widgets/app_search_field.dart';
import 'package:gravity/viewmodels/categories_viewmodel.dart';

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
      title: 'Coleções',
      subtitle: 'Gerencie suas coleções e catálogos',
      actions: [
        FilledButton.icon(
          onPressed: () => context.push('/admin/collections/new'),
          icon: const Icon(Icons.add),
          label: const Text('Nova Coleção'),
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
              title: 'Nenhuma coleção',
              message:
                  'Crie sua primeira coleção para organizar seus produtos.',
              actionLabel: 'Criar Coleção',
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
                  hintText: 'Buscar coleções...',
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
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
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
        title: const Text('Excluir Coleção?'),
        content: const Text(
          'Esta ação não pode ser desfeita. Os produtos vinculados perderão esta associação.',
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
                  ? Image.file(
                      File(coverPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                    )
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
                            Text(
                              collection.safeName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
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
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: AppTokens.textMuted.withOpacity(0.5),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Sem capa',
            style: TextStyle(
              color: AppTokens.textMuted.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
