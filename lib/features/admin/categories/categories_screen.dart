import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart'; // Para SyncProgress
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_search_field.dart';

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
    final role = ref.watch(currentRoleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Categorias',
      subtitle: 'Organize seus produtos por tipo',
      body: Column(
        children: [
          _buildHeader(context, role, notifier, isDark),
          if (syncProgress.isSyncing)
            _buildSyncProgressBanner(context, syncProgress),
          Expanded(
            child: state.when(
              data: (categoriesState) {
                final categories = categoriesState.categories.where((c) {
                  final nameMatch = c.safeName.toLowerCase().contains(
                    categoriesState.searchQuery.toLowerCase(),
                  );
                  return nameMatch;
                }).toList();

                if (categories.isEmpty) {
                  final isSearching = categoriesState.searchQuery.isNotEmpty;
                  return AppEmptyState(
                    icon: Icons.category_outlined,
                    title: isSearching
                        ? 'Nenhuma categoria encontrada'
                        : 'Nenhuma categoria',
                    subtitle: isSearching
                        ? 'Tente buscar por outro termo.'
                        : 'Crie categorias para organizar seus produtos.',
                    actionLabel: isSearching ? null : 'Criar categoria',
                    onAction: isSearching
                        ? null
                        : () => _showCategoryDialog(context, notifier),
                    message: '',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final count =
                        categoriesState.productCounts[category.id] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.03)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Theme.of(context).dividerColor.withOpacity(0.1),
                        ),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTokens.electricBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            category.type == CategoryType.collection
                                ? Icons.collections_bookmark_outlined
                                : Icons.category_outlined,
                            size: 22,
                            color: AppTokens.vibrantCyan,
                          ),
                        ),
                        title: Text(
                          category.safeName,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '$count ${count == 1 ? 'produto' : 'produtos'}',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.edit_note_rounded,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
                          onPressed: () => _showCategoryDialog(
                            context,
                            notifier,
                            category: category,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => AppErrorView(
                error: e,
                stackTrace: s,
                onRetry: () => notifier.refresh(),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () => _showCategoryDialog(context, notifier),
          label: const Text(
            'NOVA CATEGORIA',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          icon: const Icon(Icons.add_rounded),
          backgroundColor: AppTokens.softPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    UserRole role,
    CategoriesViewModel notifier,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: isDark
            ? AppTokens.deepNavy.withOpacity(0.5)
            : Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox.shrink(),
              const Spacer(),
              if (role.canManageRegistrations)
                _buildMoreActions(context, notifier, isDark),
            ],
          ),
          const SizedBox(height: 24),
          AppSearchField(
            controller: _searchController,
            hintText: 'Buscar categorias...',
            onChanged: (val) => ref
                .read(categoriesViewModelProvider.notifier)
                .setSearchQuery(val),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreActions(
    BuildContext context,
    CategoriesViewModel notifier,
    bool isDark,
  ) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: isDark ? Colors.white : Colors.black54,
      ),
      onSelected: (value) {
        if (value == 'upload') _startCloudSync(context, notifier);
        if (value == 'download') _startCloudDownload(context, notifier);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'upload',
          child: Row(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 20),
              SizedBox(width: 8),
              Text('Subir p/ Nuvem'),
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
          content: Text(
            result.message ?? 'Não é possível excluir esta categoria.',
          ),
          backgroundColor: AppTokens.accentRed,
        ),
      );
    }
  }

  void _startCloudSync(
    BuildContext context,
    CategoriesViewModel notifier,
  ) async {
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
    CategoriesViewModel notifier,
  ) async {
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
