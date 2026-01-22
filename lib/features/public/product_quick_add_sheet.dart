import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/viewmodels/cart_viewmodel.dart';
import 'package:intl/intl.dart';

class ProductQuickAddSheet extends ConsumerStatefulWidget {
  final Product product;

  const ProductQuickAddSheet({super.key, required this.product});

  @override
  ConsumerState<ProductQuickAddSheet> createState() => _ProductQuickAddSheetState();
}

class _ProductQuickAddSheetState extends ConsumerState<ProductQuickAddSheet> {
  int _quantity = 1;
  String? _selectedSize;

  @override
  void initState() {
    super.initState();
    if (widget.product.sizes.isNotEmpty) {
      _selectedSize = widget.product.sizes.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.product.images.isNotEmpty)
                Container(
                  width: 80, height: 80,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(File(widget.product.images.first)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(widget.product.name, style: Theme.of(context).textTheme.titleLarge),
                     Text(currency.format(widget.product.retailPrice), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green)),
                   ],
                 ),
               ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (widget.product.sizes.isNotEmpty) ...[
             const Text('Tamanho', style: TextStyle(fontWeight: FontWeight.bold)),
             const SizedBox(height: 8),
             Wrap(
               spacing: 8,
               children: widget.product.sizes.map((s) => ChoiceChip(
                 label: Text(s),
                 selected: _selectedSize == s,
                 onSelected: (val) => setState(() => _selectedSize = val ? s : null),
               )).toList(),
             ),
             const SizedBox(height: 24),
          ],
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quantidade', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove), 
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16)
              ),
              onPressed: () {
                if (widget.product.sizes.isNotEmpty && _selectedSize == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um tamanho')));
                  return;
                }
                
                ref.read(cartViewModelProvider.notifier).addToCart(widget.product, _quantity, _selectedSize);
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Adicionado ao carrinho!'), duration: Duration(seconds: 1)
                ));
              },
              child: Text('Adicionar - ${currency.format(widget.product.retailPrice * _quantity)}'),
            ),
          ),
        ],
      ),
    );
  }
}
