import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:intl/intl.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_search_field.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';

class ProductsSelectionTab extends StatefulWidget {
  final List<String> selectedIds;
  final Function(String) onToggle;
  final List<Product> allProducts;
  final List<Category> categories;

  const ProductsSelectionTab({
    super.key,
    required this.selectedIds,
    required this.onToggle,
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
  bool _onlySelected = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allProducts.where((p) {
      if (_onlySelected && !widget.selectedIds.contains(p.id)) return false;
      if (_categoryFilter != null && !p.categoryIds.contains(_categoryFilter)) {
        return false;
      }
      if (_search.isNotEmpty) {
        if (!p.name.toLowerCase().contains(_search.toLowerCase()) &&
            !p.reference.toLowerCase().contains(_search.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space24,
            vertical: AppTokens.space12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSearchField(
                controller: _searchController,
                hintText: 'Buscar por nome ou REF...',
                onChanged: (val) => setState(() => _search = val),
                onClear: () {
                  setState(() => _search = '');
                  _searchController.clear();
                },
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      label: Text(_categoryLabel()),
                      onPressed: () => _selectCategory(context),
                      avatar: const Icon(Icons.filter_list, size: 16),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Apenas Selecionados'),
                      selected: _onlySelected,
                      onSelected: (val) => setState(() => _onlySelected = val),
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
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const AppEmptyState(
                  icon: Icons.search_off,
                  title: 'Nenhum produto encontrado',
                  message: 'Tente ajustar os filtros ou a busca.',
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
                    final isSelected = widget.selectedIds.contains(product.id);
                    return _ProductSelectTile(
                      product: product,
                      isSelected: isSelected,
                      onToggle: () => widget.onToggle(product.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _categoryLabel() {
    if (_categoryFilter == null) return 'Categoria: Todas';
    final name = widget.categories
        .where((c) => c.id == _categoryFilter)
        .map((c) => c.name)
        .toList();
    if (name.isEmpty) return 'Categoria: Todas';
    return 'Categoria: ${name.first}';
  }

  Future<void> _selectCategory(BuildContext context) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Categoria',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: const Text('Todas categorias'),
              trailing: _categoryFilter == null
                  ? const Icon(Icons.check)
                  : const SizedBox(),
              onTap: () => Navigator.pop(sheetContext, null),
            ),
            ...widget.categories.map(
              (category) => ListTile(
                title: Text(category.safeName),
                trailing: _categoryFilter == category.id
                    ? const Icon(Icons.check)
                    : const SizedBox(),
                onTap: () => Navigator.pop(sheetContext, category.id),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _categoryFilter = result);
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
        leading: _ProductThumb(
          imagePath: product.images.isNotEmpty ? product.images.first : null,
        ),
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
}

class _ProductThumb extends StatelessWidget {
  final String? imagePath;

  const _ProductThumb({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: (imagePath != null && !kIsWeb)
            ? Image.file(
                File(imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
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
