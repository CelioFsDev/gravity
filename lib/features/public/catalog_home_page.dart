import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/viewmodels/cart_viewmodel.dart';
import 'package:gravity/viewmodels/catalog_public_viewmodel.dart';
import 'package:gravity/features/public/cart_side_panel.dart';
import 'package:gravity/features/public/product_quick_add_sheet.dart';
import 'package:intl/intl.dart';

class CatalogHomePage extends ConsumerStatefulWidget {
  final String slug;

  const CatalogHomePage({super.key, required this.slug});

  @override
  ConsumerState<CatalogHomePage> createState() => _CatalogHomePageState();
}

class _CatalogHomePageState extends ConsumerState<CatalogHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogPublicProvider(widget.slug));
    final cart = ref.watch(cartViewModelProvider);

    return catalogAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Erro ao carregar catálogo: $e'))),
      data: (data) {
        if (data == null) {
          return const Scaffold(body: Center(child: Text('Catálogo não encontrado')));
        }
        if (!data.catalog.active) {
          return const Scaffold(body: Center(child: Text('Catálogo indisponível')));
        }
        
        final filteredProducts = _selectedCategoryId == null 
            ? data.products 
            : data.products.where((p) => p.categoryId == _selectedCategoryId).toList();

        return Scaffold(
          key: _scaffoldKey,
          endDrawer: CartSidePanel(catalog: data.catalog),
          appBar: AppBar(
            title: Text(data.catalog.name),
            centerTitle: true,
            actions: [
              Stack(
                children: [
                   IconButton(icon: const Icon(Icons.shopping_bag_outlined), onPressed: () {
                     _scaffoldKey.currentState?.openEndDrawer();
                   }),
                   if (cart.items.isNotEmpty)
                     Positioned(
                       right: 8, top: 8,
                       child: Container(
                         padding: const EdgeInsets.all(4),
                         decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                         child: Text('${cart.items.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                       ),
                     ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
               // Announcement
               if (data.catalog.announcementEnabled && data.catalog.announcementText != null)
                 Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.amber.shade100,
                    child: Text(data.catalog.announcementText!, textAlign: TextAlign.center),
                 ),
                 
               // Categories Chips
               if (data.categories.isNotEmpty)
                 SizedBox(
                   height: 60,
                   child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      scrollDirection: Axis.horizontal,
                      itemCount: data.categories.length + 1,
                      separatorBuilder: (_,__) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ChoiceChip(
                            label: const Text('Todos'), 
                            selected: _selectedCategoryId == null,
                            onSelected: (v) => setState(() => _selectedCategoryId = null),
                          );
                        }
                        final cat = data.categories[index - 1];
                         return ChoiceChip(
                            label: Text(cat.name), 
                            selected: _selectedCategoryId == cat.id,
                            onSelected: (v) => setState(() => _selectedCategoryId = v ? cat.id : null),
                          );
                      },
                   ),
                 ),
                 
               // Products Grid/List
               Expanded(
                 child: filteredProducts.isEmpty
                     ? const Center(child: Text('Nenhum produto encontrado'))
                     : _buildProductLayout(filteredProducts, data.catalog.photoLayout),
               ),
            ],
          ),
          // Floating Cart Button (optional, but requested)
          floatingActionButton: cart.items.isNotEmpty 
             ? FloatingActionButton.extended(
                 onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                 icon: const Icon(Icons.shopping_bag),
                 label: Text('${cart.items.length} itens'),
               )
             : null,
        );
      },
    );
  }

  Widget _buildProductLayout(List<Product> products, String layout) {
     final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
     
     if (layout == 'list') {
       return ListView.builder(
         padding: const EdgeInsets.all(16),
         itemCount: products.length,
         itemBuilder: (context, index) {
            final product = products[index];
            return Card(
               margin: const EdgeInsets.only(bottom: 16),
               child: ListTile(
                   leading: Container(
                     width: 60, height: 60,
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(8),
                       image: product.images.isNotEmpty ? DecorationImage(image: FileImage(File(product.images.first)), fit: BoxFit.cover) : null,
                       color: Colors.grey.shade200,
                     ),
                   ),
                   title: Text(product.name),
                   subtitle: Text('REF: ${product.reference}'),
                   trailing: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       Text(currency.format(product.retailPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     ],
                   ),
                   onTap: product.isOutOfStock ? null : () => _showQuickAdd(product),
               ),
            );
         },
       );
     }
     
     // Grid and Carousel (treated as Grid for now, real carousel needs different widget structure)
     // Prompt just said "photoLayout: grid, carousel, parallel".
     // Carousel usually means horizontal scroll or slider. Grid is vertical. 
     // Parallel could be 1 column? 
     // For now implementing Grid as safe default and Carousel layout as 1 column large image ("Instagram style").
     
     final isLarge = layout == 'carousel'; // mapping "carousel" to large cards 1 per row for vertical scroll
                                           // or maybe strict carousel? Let's assume vertical list of large cards.
     
     return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
           crossAxisCount: isLarge ? 1 : 2,
           childAspectRatio: isLarge ? 1.5 : 0.7,
           crossAxisSpacing: 16,
           mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
           final product = products[index];
           return GestureDetector(
             onTap: product.isOutOfStock ? null : () => _showQuickAdd(product),
             child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (product.images.isNotEmpty)
                             Image.file(File(product.images.first), fit: BoxFit.cover)
                          else
                             Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported)),
                          if (product.isOutOfStock)
                             Container(
                               color: Colors.black54,
                               alignment: Alignment.center,
                               child: const Text('ESGOTADO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(currency.format(product.retailPrice), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
             ),
           );
        },
     );
  }
  
  void _showQuickAdd(Product product) {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      builder: (context) => ProductQuickAddSheet(product: product),
    );
  }
}
