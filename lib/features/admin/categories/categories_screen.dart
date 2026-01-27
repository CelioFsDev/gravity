import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/viewmodels/categories_viewmodel.dart';
import 'package:gravity/core/widgets/responsive_scaffold.dart';

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

    return ResponsiveScaffold(
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categorias',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Organize as categorias do catálogo',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(context, notifier),
                icon: const Icon(Icons.add),
                label: const Text('Nova categoria'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 500;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isWide
                          ? constraints.maxWidth - 200
                          : constraints.maxWidth,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Buscar categorias...',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                        ),
                        onChanged: notifier.setSearchQuery,
                      ),
                    ),
                    if (isWide) const VerticalDivider(),
                    DropdownButton<CategorySortOption>(
                      value: state.sortOption,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: CategorySortOption.manual,
                          child: Text('Ordem Manual'),
                        ),
                        DropdownMenuItem(
                          value: CategorySortOption.aToZ,
                          child: Text('A - Z'),
                        ),
                        DropdownMenuItem(
                          value: CategorySortOption.zToA,
                          child: Text('Z - A'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) notifier.setSortOption(val);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: state.categories.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Nenhuma categoria encontrada.'),
                    ),
                  )
                : _buildCategoriesList(state, notifier),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(
    CategoriesState state,
    CategoriesViewModel notifier,
  ) {
    if (state.sortOption == CategorySortOption.manual &&
        state.searchQuery.isEmpty) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: true,
        padding: EdgeInsets.zero,
        itemCount: state.categories.length,
        onReorder: (oldIndex, newIndex) {
          notifier.reorder(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          return _buildListItem(
            context,
            state.categories[index],
            state.productCounts,
            notifier,
            index,
          );
        },
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: state.categories.length,
      itemBuilder: (context, index) {
        return _buildListItem(
          context,
          state.categories[index],
          state.productCounts,
          notifier,
          index,
        );
      },
    );
  }

  Widget _buildListItem(
    BuildContext context,
    Category category,
    Map<String, int> counts,
    CategoriesViewModel notifier,
    int index,
  ) {
    return Card(
      key: ValueKey(category.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.drag_handle, color: Colors.grey),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${counts[category.id] ?? 0} produtos'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () =>
                  _showCategoryDialog(context, notifier, category: category),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _handleDelete(context, notifier, category),
            ),
          ],
        ),
      ),
    );
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
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Editar Categoria' : 'Nova Categoria'),
        content: TextField(
          controller: _categoryNameController,
          focusNode: _categoryNameFocus,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Nome',
            hintText: 'Ex: Camisetas',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _categoryNameController.text;
              if (name.trim().isEmpty) return;

              String? error;
              if (isEdit) {
                error = await notifier.updateCategory(category.id, name);
              } else {
                error = await notifier.addCategory(name);
              }

              if (context.mounted) {
                if (error != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error)));
                } else {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (mounted) {
      _categoryNameController.clear();
      _categoryNameFocus.unfocus();
    }
  }

  Future<void> _handleDelete(
    BuildContext context,
    CategoriesViewModel notifier,
    Category category,
  ) async {
    final result = await notifier.checkDelete(category.id);
    if (!context.mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Categoria excluída')));
      return;
    }

    // Has products dialogue
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Categoria?'),
        content: const Text(
          'Esta categoria possui produtos vinculados.\nO que deseja fazer?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          OutlinedButton(
            child: const Text('Mover para "Sem Categoria"'),
            onPressed: () async {
              // Creating or Checking for "Uncategorized" logic needs to happen in VM or here.
              // VM `deleteAndUncategorize` handles setting empty string.
              await notifier.deleteAndUncategorize(category.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir Mesmo Assim'),
            onPressed: () async {
              // Also sets to uncategorized per requirement "definir categoryId = null"
              // Basically same as above but explicit choice for user feeling.
              await notifier.deleteAndUncategorize(category.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
