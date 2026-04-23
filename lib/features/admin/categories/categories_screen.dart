import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart'; // Para SyncProgress
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final _searchController = TextEditingController();
  final _categoryNameController = TextEditingController();
  final _categoryNameFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _categoryNameFocus.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoriesViewModelProvider);
    final notifier = ref.read(categoriesViewModelProvider.notifier);
    final syncProgress = ref.watch(syncProgressProvider);

    return AppScaffold(
      title: 'Categorias',
      subtitle: 'Organize as categorias do catálogo',
      actions: [
        if (ref.watch(currentRoleProvider).canManageRegistrations)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'add') _showCategoryDialog(context, notifier);
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
                    Text('Nova Categoria'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'upload',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Sincronizar Nuvem'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.cloud_download_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Baixar da Nuvem'),
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
              data: (categoriesState) {
                final categories = categoriesState.categories.where((c) {
                  final nameMatch = c.safeName
                      .toLowerCase()
                      .contains(categoriesState.searchQuery.toLowerCase());
                  return nameMatch;
                }).toList();

                if (categories.isEmpty) {
                  final isSearching = categoriesState.searchQuery.isNotEmpty;
                  return AppEmptyState(
                    icon: Icons.category_outlined,
                    title: isSearching ? 'Nenhuma categoria encontrada' : 'Nenhuma categoria',
                    message: isSearching
                        ? 'Tente buscar por outro termo.'
                        : 'Crie categorias para organizar seus produtos.',
                    actionLabel: isSearching ? null : 'Criar categoria',
                    onAction: isSearching ? null : () => _showCategoryDialog(context, notifier),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space24,
                    vertical: AppTokens.space16,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final count = categoriesState.productCounts[category.id] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            category.type == CategoryType.collection
                                ? Icons.collections_bookmark_outlined
                                : Icons.category_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          category.safeName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '$count ${count == 1 ? 'produto' : 'produtos'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showCategoryDialog(
                                context,
                                notifier,
                                category: category,
                              ),
                            ),
                            PopupMenuButton<_CategoryAction>(
                              icon: const Icon(Icons.more_horiz, size: 20),
                              onSelected: (action) {
                                if (action == _CategoryAction.delete) {
                                  _handleDelete(context, notifier, category);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: _CategoryAction.delete,
                                  child: Text('Excluir'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => AppErrorView(
                error: e,
                onRetry: () => ref.invalidate(categoriesViewModelProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCategory(
    CategoriesViewModel notifier,
    bool isEdit,
    Category? category,
  ) async {
    final name = _categoryNameController.text.trim();
    if (name.isEmpty) return;

    try {
      final error = isEdit && category != null
          ? await notifier.updateCategory(category.id, name)
          : await notifier.addCategory(name, CategoryType.productType);

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar categoria: $e')));
    }
  }

  Future<void> _showCategoryDialog(
    BuildContext context,
    CategoriesViewModel notifier, {
    Category? category,
  }) async {
    final isEdit = category != null;
    _categoryNameController.text = category?.name ?? '';
    _categoryNameController.selection = TextSelection.collapsed(
      offset: _categoryNameController.text.length,
    );

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: Text(isEdit ? 'Editar Categoria' : 'Nova Categoria'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _categoryNameController,
                focusNode: _categoryNameFocus,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex: Camisetas',
                ),
                autofocus: true,
                onSubmitted: (_) {
                  _saveCategory(notifier, isEdit, category);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => _saveCategory(notifier, isEdit, category),
              child: Text(isEdit ? 'Salvar' : 'Criar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDelete(
    BuildContext context,
    CategoriesViewModel notifier,
    Category category,
  ) async {
    final result = await notifier.checkDelete(category.id);
    if (!context.mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoria excluída com sucesso.')),
      );
      return;
    }

    if (result.hasProducts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Não é possível excluir esta categoria.'),
          backgroundColor: AppTokens.accentRed,
        ),
      );
    }
  }

  void _startCloudSync(BuildContext context, CategoriesViewModel notifier) async {
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

  void _startCloudDownload(BuildContext context, CategoriesViewModel notifier) async {
    try {
      await notifier.syncFromCloud();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar categorias: $e'),
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

enum _CategoryAction { delete }
