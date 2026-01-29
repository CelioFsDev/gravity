import 'dart:async';

import 'package:gravity/data/repositories/contracts/orders_repository_contract.dart';
import 'package:gravity/models/order.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'orders_repository.g.dart';

Stream<List<T>> _boxValuesStream<T>(Box<T> box) {
  return Stream<List<T>>.multi((controller) {
    controller.add(box.values.toList());
    final subscription = box.watch().listen((_) {
      controller.add(box.values.toList());
    });
    controller.onCancel = subscription.cancel;
  });
}

class HiveOrdersRepository implements OrdersRepositoryContract {
  final Box<Order> _box;

  HiveOrdersRepository(this._box);

  Box<Order> get box => _box;

  @override
  Future<List<Order>> getOrders() async => _box.values.toList();

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

  @override
  Stream<List<Order>> watchOrders() => _boxValuesStream(_box);
}

@Riverpod(keepAlive: true)
OrdersRepositoryContract ordersRepository(OrdersRepositoryRef ref) {
  final ordersBox = Hive.box<Order>('orders');
  return HiveOrdersRepository(ordersBox);
}
