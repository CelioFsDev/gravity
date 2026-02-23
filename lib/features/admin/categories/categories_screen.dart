import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/viewmodels/categories_viewmodel.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_scaffold.dart';
import 'package:gravity/ui/widgets/app_search_field.dart';
import 'package:gravity/ui/widgets/app_empty_state.dart';

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

    return AppScaffold(
      title: 'Categorias',
      subtitle: 'Organize as categorias do catálogo',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showCategoryDialog(context, notifier),
          tooltip: 'Nova Categoria',
        ),
      ],
      body: state.when(
        data: (data) => _buildContent(context, data, notifier),
        error: (e, s) => Center(child: Text('Erro: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    CategoriesState state,
    CategoriesViewModel notifier,
  ) {
    if (_searchController.text != state.searchQuery) {
      _searchController.value = TextEditingValue(
        text: state.searchQuery,
        selection: TextSelection.collapsed(offset: state.searchQuery.length),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
          child: AppSearchField(
            controller: _searchController,
            hintText: 'Buscar categorias...',
            onChanged: notifier.setSearchQuery,
            onClear: () {
              notifier.setSearchQuery('');
              _searchController.clear();
            },
          ),
        ),
        const SizedBox(height: AppTokens.space8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
          child: Row(
            children: [
              ActionChip(
                label: Text(_sortLabel(state.sortOption)),
                onPressed: () => _selectSort(context, state, notifier),
                avatar: const Icon(Icons.sort, size: 16),
              ),
              if (state.searchQuery.isNotEmpty ||
                  state.sortOption != CategorySortOption.manual) ...[
                const SizedBox(width: 8),
                ActionChip(
                  label: const Text('Limpar'),
                  onPressed: () {
                    notifier.setSearchQuery('');
                    notifier.setSortOption(CategorySortOption.manual);
                    _searchController.clear();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space16),
        Expanded(
          child: state.categories.isEmpty
              ? const AppEmptyState(
                  icon: Icons.folder_open,
                  title: 'Nenhuma categoria',
                  message: 'Toque no + para criar sua primeira categoria.',
                )
              : _buildCategoriesList(state, notifier),
        ),
      ],
    );
  }

  Widget _buildCategoriesList(
    CategoriesState state,
    CategoriesViewModel notifier,
  ) {
    final isManual =
        state.sortOption == CategorySortOption.manual &&
        state.searchQuery.isEmpty;

    final query = state.searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? state.categories
        : state.categories
              .where((c) => c.safeName.toLowerCase().contains(query))
              .toList();

    // Filter ONLY product types
    final productTypes = filtered
        .where((c) => c.type == CategoryType.productType)
        .toList();

    if (productTypes.isEmpty) {
      return const Center(child: Text('Nenhuma categoria encontrada.'));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space24,
        vertical: AppTokens.space12,
      ),
      children: [
        _buildSectionList(
          context,
          state,
          notifier,
          productTypes,
          isManual: isManual,
        ),
      ],
    );
  }

  Widget _buildSectionList(
    BuildContext context,
    CategoriesState state,
    CategoriesViewModel notifier,
    List<Category> categories, {
    required bool isManual,
  }) {
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Nenhum item nesta secao.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    if (isManual) {
      final indices = categories
          .map((c) => state.categories.indexWhere((e) => e.id == c.id))
          .toList();
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        onReorder: (oldIndex, newIndex) {
          final oldFull = indices[oldIndex];
          final newFull = indices[math.min(newIndex, indices.length - 1)];
          notifier.reorder(oldFull, newFull);
        },
        itemBuilder: (context, index) {
          return _buildListItem(
            context,
            state,
            notifier,
            categories[index],
            indices[index],
            isManual: true,
          );
        },
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return _buildListItem(
          context,
          state,
          notifier,
          categories[index],
          index,
          isManual: false,
        );
      },
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    CategoriesState state,
    CategoriesViewModel notifier,
    Category category,
    int index, {
    required bool isManual,
  }) {
    return Container(
      key: ValueKey(category.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        leading: isManual
            ? ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: Colors.grey),
              )
            : const Icon(Icons.folder_outlined, color: Colors.grey),
        title: Text(
          category.safeName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${state.productCounts[category.id] ?? 0} produtos'),
        trailing: PopupMenuButton<_CategoryAction>(
          tooltip: 'Ações',
          onSelected: (value) {
            if (value == _CategoryAction.edit) {
              _showCategoryDialog(context, notifier, category: category);
            } else if (value == _CategoryAction.delete) {
              _handleDelete(context, notifier, category);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: _CategoryAction.edit, child: Text('Editar')),
            PopupMenuItem(
              value: _CategoryAction.delete,
              child: Text('Excluir'),
            ),
          ],
        ),
      ),
    );
  }

  String _sortLabel(CategorySortOption option) {
    switch (option) {
      case CategorySortOption.manual:
        return 'Ordem: Manual';
      case CategorySortOption.aToZ:
        return 'Ordem: A-Z';
      case CategorySortOption.zToA:
        return 'Ordem: Z-A';
    }
  }

  Future<void> _selectSort(
    BuildContext context,
    CategoriesState state,
    CategoriesViewModel notifier,
  ) async {
    final result = await showModalBottomSheet<CategorySortOption>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Ordenar categorias',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...CategorySortOption.values.map(
              (option) => RadioListTile<CategorySortOption>(
                title: Text(_sortLabel(option)),
                value: option,
                groupValue: state.sortOption,
                onChanged: (value) => Navigator.pop(sheetContext, value),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      notifier.setSortOption(result);
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
          scrollable: false,
          title: Text(isEdit ? 'Editar Categoria' : 'Nova Categoria'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.3,
            ),
            child: Column(
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
                    // trigger save action via button press logic usually, or duplicate logic here
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (_categoryNameController.text.trim().isEmpty) return;

                if (isEdit) {
                  notifier.updateCategory(
                    category.id,
                    _categoryNameController.text.trim(),
                  );
                } else {
                  notifier.addCategory(
                    _categoryNameController.text.trim(),
                    CategoryType.productType, // Always product type here
                  );
                }
                Navigator.of(context).pop();
              },
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
        SnackBar(content: Text(result.message ?? 'Não é possível excluir.')),
      );
    }
  }
}

enum _CategoryAction { edit, delete }
