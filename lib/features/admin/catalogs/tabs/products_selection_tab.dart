import 'dart:convert';
import 'dart:io';

import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_search_field.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductsSelectionTab extends StatefulWidget {
  final List<String> selectedIds;
  final void Function(String) onToggle;
  final ValueChanged<List<String>> onSelectMany;
  final ValueChanged<List<String>> onDeselectMany;
  final List<Product> allProducts;
  final List<Category> categories;

  const ProductsSelectionTab({
    super.key,
    required this.selectedIds,
    required this.onToggle,
    required this.onSelectMany,
    required this.onDeselectMany,
    required this.allProducts,
    required this.categories,
  });

  @override
  State<ProductsSelectionTab> createState() => _ProductsSelectionTabState();
}

class _ProductsSelectionTabState extends State<ProductsSelectionTab> {
  final _searchController = TextEditingController();
  String _search = '';
  String? _categoryFilter;
  String? _collectionFilter;
  bool _onlySelected = false;
  bool _onlyWithPhoto = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIdSet = widget.selectedIds.toSet();
    final collections = widget.categories
        .where((category) => category.type == CategoryType.collection)
        .toList();
    final productTypes = widget.categories
        .where((category) => category.type == CategoryType.productType)
        .toList();

    final filtered = widget.allProducts.where((product) {
      if (_onlySelected && !selectedIdSet.contains(product.id)) {
        return false;
      }
      if (_onlyWithPhoto && product.photos.isEmpty && product.images.isEmpty) {
        return false;
      }
      if (_collectionFilter != null &&
          !product.categoryIds.contains(_collectionFilter)) {
        return false;
      }
      if (_categoryFilter != null &&
          !product.categoryIds.contains(_categoryFilter)) {
        return false;
      }
      if (_search.isNotEmpty) {
        final query = _search.toLowerCase();
        if (!product.name.toLowerCase().contains(query) &&
            !product.reference.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppTokens.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space24,
                ),
                child: AppSearchField(
                  controller: _searchController,
                  hintText: 'Buscar por nome ou REF...',
                  onChanged: (value) => setState(() => _search = value),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space24,
                ),
                child: Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.collections_bookmark, size: 16),
                      label: Text(_collectionLabel(collections)),
                      onPressed: () => _selectCollection(context, collections),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.filter_list, size: 16),
                      label: Text(_categoryLabel(productTypes)),
                      onPressed: () => _selectCategory(context, productTypes),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Apenas Selecionados'),
                      selected: _onlySelected,
                      onSelected: (value) =>
                          setState(() => _onlySelected = value),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Somente com foto'),
                      selected: _onlyWithPhoto,
                      onSelected: (value) =>
                          setState(() => _onlyWithPhoto = value),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${widget.selectedIds.length} selecionados'),
                      backgroundColor: AppTokens.accentBlue.withOpacity(0.1),
                      side: BorderSide.none,
                      labelStyle: const TextStyle(
                        color: AppTokens.accentBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.done_all, size: 16),
                      label: const Text('Selecionar todos'),
                      onPressed: filtered.isEmpty
                          ? null
                          : () => widget.onSelectMany(
                              filtered.map((product) => product.id).toList(),
                            ),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.remove_done, size: 16),
                      label: const Text('Limpar visiveis'),
                      onPressed: filtered.isEmpty
                          ? null
                          : () => widget.onDeselectMany(
                              filtered.map((product) => product.id).toList(),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const AppEmptyState(
                  icon: Icons.search_off,
                  title: 'Nenhum produto encontrado',
                  subtitle: 'Tente ajustar os filtros ou a busca.',
                  message: '',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space24,
                    vertical: AppTokens.space16,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return _ProductSelectTile(
                      product: product,
                      isSelected: selectedIdSet.contains(product.id),
                      onToggle: () => widget.onToggle(product.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _categoryLabel(List<Category> categories) {
    if (_categoryFilter == null) return 'Categoria: Todas';
    final selected = categories
        .where((category) => category.id == _categoryFilter)
        .firstOrNull;
    if (selected == null) return 'Categoria: Todas';
    return 'Categoria: ${selected.safeName}';
  }

  String _collectionLabel(List<Category> collections) {
    if (_collectionFilter == null) return 'Colecao: Todas';
    final selected = collections
        .where((category) => category.id == _collectionFilter)
        .firstOrNull;
    if (selected == null) return 'Colecao: Todas';
    return 'Colecao: ${selected.safeName}';
  }

  Future<void> _selectCategory(
    BuildContext context,
    List<Category> categories,
  ) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'Categoria',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      title: const Text('Todas categorias'),
                      trailing: _categoryFilter == null
                          ? const Icon(Icons.check)
                          : const SizedBox.shrink(),
                      onTap: () => Navigator.pop(sheetContext, null),
                    ),
                    ...categories.map(
                      (category) => ListTile(
                        title: Text(category.safeName),
                        trailing: _categoryFilter == category.id
                            ? const Icon(Icons.check)
                            : const SizedBox.shrink(),
                        onTap: () => Navigator.pop(sheetContext, category.id),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _categoryFilter = result);
  }

  Future<void> _selectCollection(
    BuildContext context,
    List<Category> collections,
  ) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'Colecao',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      title: const Text('Todas colecoes'),
                      trailing: _collectionFilter == null
                          ? const Icon(Icons.check)
                          : const SizedBox.shrink(),
                      onTap: () => Navigator.pop(sheetContext, null),
                    ),
                    ...collections.map(
                      (collection) => ListTile(
                        title: Text(collection.safeName),
                        trailing: _collectionFilter == collection.id
                            ? const Icon(Icons.check)
                            : const SizedBox.shrink(),
                        onTap: () => Navigator.pop(sheetContext, collection.id),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _collectionFilter = result);
  }
}

class _ProductSelectTile extends StatelessWidget {
  final Product product;
  final bool isSelected;
  final VoidCallback onToggle;

  const _ProductSelectTile({
    required this.product,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppTokens.accentBlue.withOpacity(0.05)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: isSelected
              ? AppTokens.accentBlue
              : Theme.of(context).dividerColor,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: _ProductThumb(imagePath: _resolvePrimaryImage(product)),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'REF ${product.reference} • ${currency.format(product.retailPrice)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        trailing: Checkbox.adaptive(
          value: isSelected,
          activeColor: AppTokens.accentBlue,
          onChanged: (_) => onToggle(),
        ),
        onTap: onToggle,
      ),
    );
  }

  String? _resolvePrimaryImage(Product product) {
    if (product.photos.isNotEmpty) {
      final typedPrimary = product.photos.firstWhere(
        (photo) => photo.photoType == 'P',
        orElse: () => product.photos.firstWhere(
          (photo) => photo.isPrimary,
          orElse: () => product.photos.first,
        ),
      );
      final path = typedPrimary.path.trim();
      if (path.isNotEmpty) return path;
    }

    if (product.images.isNotEmpty) {
      final index = product.mainImageIndex;
      if (index >= 0 && index < product.images.length) {
        final path = product.images[index].uri.trim();
        if (path.isNotEmpty) return path;
      }
      final fallback = product.images.first.uri.trim();
      if (fallback.isNotEmpty) return fallback;
    }

    return null;
  }
}

class _ProductThumb extends StatelessWidget {
  final String? imagePath;

  const _ProductThumb({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: _buildPreview(path, context),
      ),
    );
  }

  Widget _buildPreview(String? path, BuildContext context) {
    if (path == null || path.isEmpty) return _placeholder(context);

    if (path.startsWith('data:')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex != -1 && commaIndex + 1 < path.length) {
        try {
          final bytes = base64Decode(path.substring(commaIndex + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(context),
          );
        } catch (_) {
          return _placeholder(context);
        }
      }
      return _placeholder(context);
    }

    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    }

    if (!kIsWeb) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    }

    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }
}
