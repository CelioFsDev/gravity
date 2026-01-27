import 'package:gravity/core/services/whatsapp_share_service.dart';
import 'package:gravity/data/repositories/orders_repository.dart';
import 'package:gravity/data/repositories/settings_repository.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/order.dart';
import 'package:gravity/models/order_status.dart';
import 'package:gravity/viewmodels/cart_viewmodel.dart';
import 'package:gravity/viewmodels/dashboard_viewmodel.dart';
import 'package:gravity/viewmodels/orders_viewmodel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'checkout_viewmodel.g.dart';

@riverpod
class CheckoutViewModel extends _$CheckoutViewModel {
  @override
  FutureOr<void> build() async {}

  Future<void> submitOrder({
    required Catalog catalog,
    required CartState cart,
    required String customerName,
    required String customerPhone,
  }) async {
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
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

      await WhatsAppShareService.shareOrder(
        storePhone: storePhone,
        catalogName: catalog.name,
        items: cart.items,
        total: cart.total,
        customerName: customerName,
      );
      
      // Clear cart
      ref.read(cartViewModelProvider.notifier).clear();
      
      // Invalidate related providers to refresh UI
      ref.invalidate(ordersViewModelProvider);
      ref.invalidate(dashboardViewModelProvider);
    });
  }
}
