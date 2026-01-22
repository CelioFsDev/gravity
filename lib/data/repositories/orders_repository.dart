import 'package:gravity/models/order.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'orders_repository.g.dart';

abstract class OrdersRepository {
  Future<List<Order>> getOrders();
  Future<void> addOrder(Order order);
  Future<void> deleteOrder(String id);
  Future<void> clearOrders(); // Helper for testing/reset
}

class HiveOrdersRepository implements OrdersRepository {
  final Box<Order> _box;

  HiveOrdersRepository(this._box);

  @override
  Future<List<Order>> getOrders() async {
    return _box.values.toList();
  }

  @override
  Future<void> addOrder(Order order) async {
    await _box.put(order.id, order);
  }

  @override
  Future<void> deleteOrder(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> clearOrders() async {
    await _box.clear();
  }
}

@Riverpod(keepAlive: true)
OrdersRepository ordersRepository(OrdersRepositoryRef ref) {
  // We assume the box is opened in main.dart or via a provider that awaits initialization.
  // For simplicity here, we access the already opened box.
  // Note: Accessing Hive.box directly inside provider is okay if we ensure it's open.
  return HiveOrdersRepository(Hive.box<Order>('orders'));
}
