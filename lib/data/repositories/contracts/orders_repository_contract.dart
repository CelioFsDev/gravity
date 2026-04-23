import 'package:catalogo_ja/models/order.dart';

abstract class OrdersRepositoryContract {
  Future<Order?> getOrder(String id);
  Future<List<Order>> getOrders();
  Stream<List<Order>> watchOrders();
  Future<void> addOrder(Order order);
  Future<void> updateOrder(Order order);
  Future<void> deleteOrder(String id);
  Future<void> clearAll();
}
