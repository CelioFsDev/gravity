import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/models/category.dart';
import 'package:intl/intl.dart';
import 'package:gravity/core/widgets/filter_chips_row.dart';
import 'package:gravity/core/widgets/filter_chip_button.dart';

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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar produtos',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => setState(() => _search = val),
                ),
              ),
              const SizedBox(height: 12),
              FilterChipsRow(
                chips: [
                  FilterChipButton(
                    label: _categoryLabel(),
                    isActive: _categoryFilter != null,
                    onPressed: () => _selectCategory(context),
                  ),
                  FilterChipButton(
                    label: 'Apenas selecionados',
                    isActive: _onlySelected,
                    onPressed: () =>
                        setState(() => _onlySelected = !_onlySelected),
                  ),
                  Chip(
                    label: Text('Selecionados: ${widget.selectedIds.length}'),
                  ),
                ],
                onClear: _hasFilters()
                    ? () {
                        setState(() {
                          _search = '';
                          _categoryFilter = null;
                          _onlySelected = false;
                        });
                        _searchController.clear();
                      }
                    : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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

  bool _hasFilters() {
    return _search.isNotEmpty || _categoryFilter != null || _onlySelected;
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
                title: Text(category.name),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        leading: _ProductThumb(
          imagePath: product.images.isNotEmpty ? product.images.first : null,
        ),
        title: Text(product.name),
        subtitle: Text(
          'REF ${product.reference} • ${currency.format(product.retailPrice)}',
        ),
        trailing: Checkbox.adaptive(
          value: isSelected,
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
        color: Colors.grey.shade200,
        child: (imagePath != null && !kIsWeb)
            ? Image.file(
                File(imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return const Center(child: Icon(Icons.image_outlined, color: Colors.grey));
  }
}
