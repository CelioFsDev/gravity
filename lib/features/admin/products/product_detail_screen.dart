import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:gravity/features/admin/products/product_form_screen.dart';
import 'package:intl/intl.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for updates (e.g. if edited)
    final productsState = ref.watch(productsViewModelProvider);
    final updatedProduct = productsState.value?.allProducts.firstWhere((p) => p.id == product.id, orElse: () => product) ?? product;
    final categories = productsState.value?.categories ?? [];
    final categoryName = categories
        .firstWhere(
          (c) => c.id == updatedProduct.categoryId,
          orElse: () => Category(
            id: '',
            name: '-',
            order: 0,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .name;

    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Produto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductFormScreen(product: updatedProduct)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
               ref.read(productsViewModelProvider.notifier).deleteProduct(updatedProduct.id);
               Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images Carousel / Main Image
            if (updatedProduct.images.isNotEmpty)
              SizedBox(
                height: 300,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: updatedProduct.images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 300,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildDetailImage(updatedProduct.images[index]),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
              ),
              
            const SizedBox(height: 24),
            
            // Header Info
            Row(
              children: [
                if (!updatedProduct.isActive) _statusBadge('Inativo', Colors.grey),
                if (updatedProduct.isOutOfStock) _statusBadge('Esgotado', Colors.red),
                if (updatedProduct.isOnSale) _statusBadge('Em Promoção', Colors.orange),
              ],
            ),
            const SizedBox(height: 8),
            Text(updatedProduct.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                 Text('REF: ${updatedProduct.reference}', style: const TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(width: 16),
                 Text('SKU: ${updatedProduct.sku}', style: const TextStyle(color: Colors.grey)),
                 const SizedBox(width: 16),
                 Text('Categoria: $categoryName', style: const TextStyle(color: Colors.blue)),
              ],
            ),
            
            const Divider(height: 32),
            
            // Pricing
            Text('Preços', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth >= 720
                    ? (constraints.maxWidth - 32) / 3
                    : constraints.maxWidth;
                final cards = [
                  _buildInfoCard(context, 'Varejo', currency.format(updatedProduct.retailPrice), Icons.attach_money),
                  _buildInfoCard(context, 'Atacado', currency.format(updatedProduct.wholesalePrice), Icons.store),
                  _buildInfoCard(context, 'Mín. Atacado', '${updatedProduct.minWholesaleQty} un', Icons.inventory_2),
                ];
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: cards
                      .map((card) => SizedBox(width: cardWidth, child: card))
                      .toList(),
                );
              },
            ),
            
            const Divider(height: 32),
            
            // Attributes
            Text('Atributos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Tamanhos:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: updatedProduct.sizes.map((s) => Chip(label: Text(s))).toList(),
            ),
            const SizedBox(height: 16),
            Text('Cores:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: updatedProduct.colors.map((c) => Chip(label: Text(c))).toList(),
            ),
            
            const Divider(height: 32),
            Text('Criado em: ${DateFormat('dd/MM/yyyy HH:mm').format(updatedProduct.createdAt)}', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildDetailImage(String? imagePath) {
    if (imagePath == null || kIsWeb) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
      );
    }

    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, size: 48, color: Colors.red),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
