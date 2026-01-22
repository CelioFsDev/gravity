import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/order.dart';
import 'package:gravity/models/order_status.dart';
import 'package:gravity/viewmodels/dashboard_viewmodel.dart';
import 'package:gravity/data/repositories/orders_repository.dart';

class MockOrdersRepository implements OrdersRepository {
  final List<Order> _orders;
  MockOrdersRepository(this._orders);

  @override
  Future<List<Order>> getOrders() async => _orders;

  @override
  Future<void> addOrder(Order order) async {}

  @override
  Future<void> clearOrders() async {}

  @override
  Future<void> deleteOrder(String id) async {}
}

void main() {
  test('DashboardState should be empty when no orders exist', () async {
    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWith((ref) => MockOrdersRepository([])),
      ],
    );

    final state = await container.read(dashboardViewModelProvider.future);
    
    expect(state.totalRevenue, 0);
    expect(state.averageTicket, 0);
    expect(state.confirmedOrdersCount, 0);
    expect(state.pendingOrdersCount, 0);
  });

  test('DashboardState calculates KPIs correctly with mixed orders', () async {
    final now = DateTime.now();
    final orders = [
      Order(id: '1', total: 100, status: OrderStatus.confirmed, createdAt: now, items: [], clientName: 'A', clientPhone: '1'),
      Order(id: '2', total: 200, status: OrderStatus.paid, createdAt: now, items: [], clientName: 'B', clientPhone: '2'),
      Order(id: '3', total: 300, status: OrderStatus.delivered, createdAt: now, items: [], clientName: 'C', clientPhone: '3'),
      Order(id: '4', total: 50, status: OrderStatus.pending, createdAt: now, items: [], clientName: 'D', clientPhone: '4'),
      Order(id: '5', total: 500, status: OrderStatus.cancelled, createdAt: now, items: [], clientName: 'E', clientPhone: '5'),
    ];

    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWith((ref) => MockOrdersRepository(orders)),
      ],
    );

    final state = await container.read(dashboardViewModelProvider.future);
    
    // Revenue: 100 + 200 + 300 = 600
    expect(state.totalRevenue, 600);
    
    // Confirmed Count (valid for revenue): 3 (Confirmed, Paid, Delivered)
    expect(state.confirmedOrdersCount, 3);
    
    // Avg Ticket: 600 / 3 = 200
    expect(state.averageTicket, 200);
    
    // Pending Count: 1
    expect(state.pendingOrdersCount, 1);
  });
}
