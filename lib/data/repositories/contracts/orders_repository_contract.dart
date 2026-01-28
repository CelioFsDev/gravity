import 'dart:async';

import 'package:gravity/models/order.dart';

abstract class OrdersRepositoryContract {
  Future<List<Order>> getOrders();
  Future<void> addOrder(Order order);
  Future<void> deleteOrder(String id);
  Future<void> clearOrders();

  Stream<List<Order>> watchOrders();
}
