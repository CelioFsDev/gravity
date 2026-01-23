import 'package:gravity/data/repositories/orders_repository.dart';
import 'package:gravity/data/repositories/settings_repository.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/order.dart';
import 'package:gravity/models/order_status.dart';
import 'package:gravity/viewmodels/cart_viewmodel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

part 'checkout_viewmodel.g.dart';

@riverpod
class CheckoutViewModel extends _$CheckoutViewModel {
  @override
  void build() {}

  Future<void> submitOrder({
    required Catalog catalog,
    required CartState cart,
    required String customerName,
    required String customerPhone,
  }) async {
    final orderRepo = ref.read(ordersRepositoryProvider);

    // Create Order
    final order = Order(
      id: const Uuid().v4(),
      status: OrderStatus.pending,
      items: cart.items,
      createdAt: DateTime.now(),
      clientName: customerName,
      clientPhone: customerPhone,
      total: cart.total,
    );

    await orderRepo.addOrder(order);

    // Get Store Settings
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final settings = await settingsRepo.getSettings();
    final storePhone = settings.defaultWhatsapp;

    // Generate WhatsApp Message
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final sb = StringBuffer();
    sb.writeln('Olá! Gostaria de fazer um pedido do catálogo *${catalog.name}*:');
    sb.writeln('');
    for (var item in cart.items) {
      sb.write('${item.quantity}x ${item.productName}');
      if (item.selectedSize != null) sb.write(' (${item.selectedSize})');
      sb.writeln(' - ${currency.format(item.total)}');
    }
    sb.writeln('');
    sb.writeln('*Total: ${currency.format(cart.total)}*');
    sb.writeln('');
    if (customerName.isNotEmpty) sb.writeln('Nome: $customerName');
    
    // Launch WhatsApp
    // If storePhone is configured, send to store. Otherwise, send to self (customer) or error?
    // Requirement says: "abrir wa.me para o número padrão configurado".
    // If no store phone, we might fallback to printing or alerting, but for now let's try to use customer's phone as fallback (weird flow) or just don't open specific number if empty (opens chat picker).
    
    final targetPhone = storePhone.isNotEmpty ? storePhone : ''; 
    final cleanPhone = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(sb.toString())}');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Handle error or just try generic
      await launchUrl(url); // sometimes works w/o check
    }
    
    // Clear cart (handled by UI calling cartVM.clear() or here)
    ref.read(cartViewModelProvider.notifier).clear();
  }
}
