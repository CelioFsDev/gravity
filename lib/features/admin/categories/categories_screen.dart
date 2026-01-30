import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/viewmodels/categories_viewmodel.dart';
import 'package:gravity/core/widgets/responsive_scaffold.dart';
import 'package:gravity/core/widgets/section_header.dart';
import 'package:gravity/core/widgets/filter_chips_row.dart';
import 'package:gravity/core/widgets/filter_chip_button.dart';

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
        error: (e, s) => _CategoriesErrorState(
          message: 'Erro ao carregar categorias: $e',
          onRetry: () => ref.invalidate(categoriesViewModelProvider),
        ),
        loading: () => const _CategoriesLoadingState(),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    CategoriesState state,
    CategoriesViewModel notifier,
  ) {
    final hasFilters =
        state.searchQuery.isNotEmpty || state.sortOption != CategorySortOption.manual;

    if (_searchController.text != state.searchQuery) {
      _searchController.value = TextEditingValue(
        text: state.searchQuery,
        selection: TextSelection.collapsed(offset: state.searchQuery.length),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final padding = EdgeInsets.all(isWide ? 24 : 16);
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Categorias',
                subtitle: 'Organize as categorias do catalogo',
                primaryAction: SectionHeaderAction(
                  label: 'Nova categoria',
                  icon: Icons.add,
                  onPressed: () => _showCategoryDialog(context, notifier),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar categorias...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: notifier.setSearchQuery,
                ),
              ),
              const SizedBox(height: 12),
              FilterChipsRow(
                chips: [
                  FilterChipButton(
                    label: _sortLabel(state.sortOption),
                    isActive: state.sortOption != CategorySortOption.manual,
                    onPressed: () => _selectSort(context, state, notifier),
                  ),
                ],
                onClear: hasFilters
                    ? () {
                        notifier.setSearchQuery('');
                        notifier.setSortOption(CategorySortOption.manual);
                        _searchController.clear();
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: state.categories.isEmpty
                    ? const _CategoriesEmptyState()
                    : _buildCategoriesList(state, notifier),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesList(
    CategoriesState state,
    CategoriesViewModel notifier,
  ) {
    final isManual =
        state.sortOption == CategorySortOption.manual && state.searchQuery.isEmpty;

    if (isManual) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.zero,
        itemCount: state.categories.length,
        onReorder: notifier.reorder,
        itemBuilder: (context, index) {
          return _buildListItem(
            context,
            state,
            notifier,
            state.categories[index],
            index,
            isManual: true,
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
          state,
          notifier,
          state.categories[index],
          index,
          isManual: false,
        );
      },
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
    return Card(
      key: ValueKey(category.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: isManual
            ? ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: Colors.grey),
              )
            : const Icon(Icons.folder_outlined, color: Colors.grey),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${state.productCounts[category.id] ?? 0} produtos'),
        trailing: PopupMenuButton<_CategoryAction>(
          tooltip: 'Acoes',
          onSelected: (value) {
            if (value == _CategoryAction.edit) {
              _showCategoryDialog(context, notifier, category: category);
            } else if (value == _CategoryAction.delete) {
              _handleDelete(context, notifier, category);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _CategoryAction.edit,
              child: Text('Editar'),
            ),
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
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Categoria excluida')));
      return;
    }

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
              await notifier.deleteAndUncategorize(category.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

enum _CategoryAction { edit, delete }

class _CategoriesLoadingState extends StatelessWidget {
  const _CategoriesLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(
              6,
              (index) => Container(
                height: 72,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoriesEmptyState extends StatelessWidget {
  const _CategoriesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(Icons.folder_open, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Nenhuma categoria encontrada',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Crie categorias para organizar o catalogo.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CategoriesErrorState({
    required this.message,
    required this.onRetry,
  });

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
              Text(
                message,
                textAlign: TextAlign.center,
              ),
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

