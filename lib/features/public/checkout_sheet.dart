import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/viewmodels/cart_viewmodel.dart';
import 'package:gravity/viewmodels/checkout_viewmodel.dart';
import 'package:intl/intl.dart';

class CheckoutSheet extends ConsumerStatefulWidget {
  final Catalog catalog;

  const CheckoutSheet({super.key, required this.catalog});

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(); // Masking handled simply for now

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartViewModelProvider);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Finalizar Pedido', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (widget.catalog.requireCustomerData) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Seu Nome (Obrigatório)', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nome é obrigatório' : null,
                ),
                const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp (com DDD)', 
                border: OutlineInputBorder(),
                prefixText: '+55 ',
              ),
              validator: (v) {
                if (widget.catalog.requireCustomerData && (v == null || v.trim().isEmpty)) {
                  return 'WhatsApp é obrigatório';
                }
                return null;
              }, 
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${cart.items.length} itens'),
                  Text('Total: ${currency.format(cart.total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.send),
                label: const Text('Enviar Pedido no WhatsApp'),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await ref.read(checkoutViewModelProvider.notifier).submitOrder(
                      catalog: widget.catalog,
                      cart: cart,
                      customerName: _nameController.text,
                      customerPhone: '55${_phoneController.text}',
                    );
                    if (context.mounted) Navigator.pop(context); // Close sheet
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
