import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_badge_pill.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:catalogo_ja/ui/widgets/app_search_field.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';

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
    final role = ref.watch(currentRoleProvider);

    return AppScaffold(
      showHeader: false,
      title: 'Cole\u00e7\u00f5es',
      subtitle: 'Gerencie suas cole\u00e7\u00f5es e cat\u00e1logos',
      actions: [
        if (role.canManageRegistrations)
          FilledButton.icon(
            label: const Text('Nova Coleção'),
            icon: const Icon(Icons.add_rounded),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: _openNewCollection,
          ),
      ],
      floatingActionButton: role.canManageRegistrations
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton.extended(
                onPressed: _openNewCollection,
                label: const Text(
                  'NOVA COLEÇÃO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                backgroundColor: AppTokens.softPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : null,
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
              subtitle: '',
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
        error: (e, s) {
          if (_searchQuery.isEmpty) {
            return AppEmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'Nenhuma cole\u00e7\u00e3o',
              message:
                  'Ainda n\u00e3o h\u00e1 cole\u00e7\u00f5es cadastradas para esta empresa.',
              actionLabel: role.canManageRegistrations
                  ? 'Criar Cole\u00e7\u00e3o'
                  : null,
              onAction: role.canManageRegistrations
                  ? () => context.push('/admin/collections/new')
                  : null,
              subtitle: '',
            );
          }
          return AppErrorView(
            error: e,
            stackTrace: s,
            onRetry: () =>
                ref.read(categoriesViewModelProvider.notifier).refresh(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _openNewCollection() {
    context.push('/admin/collections/new');
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

class _CollectionCard extends ConsumerWidget {
  final Category collection;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CollectionCard({
    required this.collection,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final coverPath = collection.cover?.coverMiniPath;
    final hasCover = coverPath != null && coverPath.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: role.canManageRegistrations ? onEdit : null,
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
                  if (role.canManageRegistrations)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                      icon: const Icon(Icons.more_vert),
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
