import 'package:catalogo_ja/models/order.dart';
import 'package:catalogo_ja/data/repositories/contracts/orders_repository_contract.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HiveOrdersRepository implements OrdersRepositoryContract {
  final Box<Order> _box;

  HiveOrdersRepository(this._box);

  @override
  Future<Order?> getOrder(String id) async {
    return _box.get(id);
  }

  @override
  Future<List<Order>> getOrders() async {
    return _box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Stream<List<Order>> watchOrders() {
    return _box.watch().map((_) {
      return _box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  @override
  Future<void> addOrder(Order order) async {
    await _box.put(order.id, order);
  }

  @override
  Future<void> updateOrder(Order order) async {
    await _box.put(order.id, order);
  }

  @override
  Future<void> deleteOrder(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> clearAll() async {
    await _box.clear();
  }
}

final ordersBoxProvider = Provider<Box<Order>>((ref) {
  return Hive.box<Order>('orders');
});

final hiveOrdersRepositoryProvider = Provider<HiveOrdersRepository>((ref) {
  return HiveOrdersRepository(ref.watch(ordersBoxProvider));
});
