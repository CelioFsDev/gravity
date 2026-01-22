import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/viewmodels/cart_viewmodel.dart';
import 'package:gravity/features/public/checkout_sheet.dart';
import 'package:gravity/models/catalog.dart';
import 'package:intl/intl.dart';

class CartSidePanel extends ConsumerWidget {
  final Catalog catalog;

  const CartSidePanel({super.key, required this.catalog});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartViewModelProvider);
    final notifier = ref.read(cartViewModelProvider.notifier);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Drawer(
      width: 320,
      child: Column(
        children: [
          DrawerHeader(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 48),
                  const SizedBox(height: 8),
                  Text('Seu Pedido', style: Theme.of(context).textTheme.titleLarge),
                  Text('${cart.items.length} itens', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          Expanded(
            child: cart.items.isEmpty
                ? const Center(child: Text('Seu carrinho está vazio'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (item.selectedSize != null) 
                                  Text('Tam: ${item.selectedSize}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(currency.format(item.unitPrice), style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => notifier.updateQuantity(index, -1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('${item.quantity}'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => notifier.updateQuantity(index, 1),
                                  ),
                                ],
                              ),
                              Text(currency.format(item.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (cart.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(currency.format(cart.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Close drawer
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => CheckoutSheet(catalog: catalog),
                        );
                      },
                      child: const Text('Finalizar Pedido'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
