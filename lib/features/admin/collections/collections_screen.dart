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
      showHeader: true,
      title: 'Coleções',
      actions: [
        if (role.canManageRegistrations)
          IconButton(
            tooltip: 'Limpar caches',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(categoriesViewModelProvider),
          ),
      ],
      floatingActionButton: null,
      body: categoriesState.when(
        data: (state) {
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
              actionLabel:
                  role.canManageRegistrations ? 'Criar Coleção' : null,
              onAction:
                  role.canManageRegistrations ? _openNewCollection : null,
              subtitle: '',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  'Gerencie suas coleções e catálogos',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
              if (role.canManageRegistrations)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openNewCollection,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        'NOVA COLEÇÃO',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space24,
                  vertical: 12,
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
              const SizedBox(height: 8),
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
              title: 'Nenhuma coleção',
              message:
                  'Ainda não há coleções cadastradas para esta empresa.',
              actionLabel:
                  role.canManageRegistrations ? 'Criar Coleção' : null,
              onAction:
                  role.canManageRegistrations ? _openNewCollection : null,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
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
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTokens.accentBlue.withOpacity(0.18),
            AppTokens.vibrantCyan.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.collections_bookmark_outlined,
          color: AppTokens.accentBlue,
          size: 36,
        ),
      ),
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