import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/models/category.dart';

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
  String _search = '';
  String? _categoryFilter;
  bool _onlySelected = false;

  @override
  Widget build(BuildContext context) {
    // Filter
    final filtered = widget.allProducts.where((p) {
      if (_onlySelected && !widget.selectedIds.contains(p.id)) {
        return false;
      }
      if (_categoryFilter != null && p.categoryId != _categoryFilter) {
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
        // Filters
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar produtos',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (val) => setState(() => _search = val),
              ),
              Row(
                children: [
                  DropdownButton<String>(
                    hint: const Text('Categoria'),
                    value: _categoryFilter,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...widget.categories.map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (val) => setState(() => _categoryFilter = val),
                  ),
                  const SizedBox(width: 16),
                  FilterChip(
                    label: const Text('Apenas Selecionados'),
                    selected: _onlySelected,
                    onSelected: (val) => setState(() => _onlySelected = val),
                  ),
                  const Spacer(),
                  Text('${widget.selectedIds.length} selecionados'),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final product = filtered[index];
              final isSelected = widget.selectedIds.contains(product.id);
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (product.images.isNotEmpty && !kIsWeb)
                      ? Image.file(
                          File(product.images[0]),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image),
                        )
                      : const Center(child: Icon(Icons.image_not_supported)),
                ),
                title: Text(product.name),
                subtitle: Text(
                  'REF: ${product.reference} | R\$ ${product.retailPrice}',
                ),
                trailing: Checkbox(
                  value: isSelected,
                  onChanged: (_) => widget.onToggle(product.id),
                ),
                onTap: () => widget.onToggle(product.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
