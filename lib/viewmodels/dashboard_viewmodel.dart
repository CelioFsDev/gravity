import 'package:gravity/data/repositories/orders_repository.dart';
import 'package:gravity/models/order.dart';
import 'package:gravity/models/order_status.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_viewmodel.g.dart';

class DashboardState {
  final double totalRevenue;
  final double averageTicket;
  final int confirmedOrdersCount;
  final int pendingOrdersCount;
  // Simplified chart data for now: Map<int, double> where int is weekday
  final Map<int, double> weeklyRevenue; 
  final Map<OrderStatus, int> ordersByStatus;

  DashboardState({
    required this.totalRevenue,
    required this.averageTicket,
    required this.confirmedOrdersCount,
    required this.pendingOrdersCount,
    required this.weeklyRevenue,
    required this.ordersByStatus,
  });

  factory DashboardState.empty() {
     return DashboardState(
      totalRevenue: 0,
      averageTicket: 0,
      confirmedOrdersCount: 0,
      pendingOrdersCount: 0,
       weeklyRevenue: {},
      ordersByStatus: {},
    );
  }
}

@riverpod
class DashboardViewModel extends _$DashboardViewModel {
  @override
  FutureOr<DashboardState> build() async {
    final repository = ref.watch(ordersRepositoryProvider);
    final orders = await repository.getOrders();
    return _calculateState(orders);
  }

  DashboardState _calculateState(List<Order> orders) {
    if (orders.isEmpty) return DashboardState.empty();

    double revenue = 0;
    int confirmedCount = 0; // Count of orders that contribute to revenue/ticket
    int pendingCount = 0;
    Map<OrderStatus, int> statusCounts = {};

    // For weekly chart (placeholder logic: group by weekday of createdAt)
    Map<int, double> dailyRevenue = {};

    for (var order in orders) {
      // Update status counts
      statusCounts[order.status] = (statusCounts[order.status] ?? 0) + 1;

      // Logic: Revenue sums confirmed, paid, shipped, delivered
      // Cancelled ignored. Pending ignored for revenue? Prompt says "faturamento soma apenas status Confirmado/Pago/Enviado/Entregue"
      bool isValidRevenue = [
        OrderStatus.confirmed,
        OrderStatus.paid,
        OrderStatus.shipped,
        OrderStatus.delivered
      ].contains(order.status);

      if (isValidRevenue) {
        revenue += order.total;
        confirmedCount++;
        
        // Add to daily revenue
        // Simplify: Just use weekday 1-7. In real app, would need strict date grouping.
        final day = order.createdAt.weekday;
        dailyRevenue[day] = (dailyRevenue[day] ?? 0) + order.total;
      }

      if (order.status == OrderStatus.pending) {
        pendingCount++;
      }
    }

    double avgTicket = confirmedCount > 0 ? revenue / confirmedCount : 0;

    return DashboardState(
      totalRevenue: revenue,
      averageTicket: avgTicket,
      confirmedOrdersCount: confirmedCount,
      pendingOrdersCount: pendingCount,
      weeklyRevenue: dailyRevenue,
      ordersByStatus: statusCounts,
    );
  }
  
  // Helper to refresh data
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(ordersRepositoryProvider);
      final orders = await repository.getOrders();
      return _calculateState(orders);
    });
  }
  
  // Helper to seed data for testing
  Future<void> seedData() async {
    final repository = ref.read(ordersRepositoryProvider);
    await repository.clearOrders();
    
    final now = DateTime.now();
    final orders = [
      Order(id: '1', total: 100, status: OrderStatus.confirmed, createdAt: now, items: [], clientName: 'João Silva', clientPhone: '5511999999999'),
      Order(id: '2', total: 200, status: OrderStatus.paid, createdAt: now.subtract(const Duration(days: 1)), items: [], clientName: 'Maria Oliveira', clientPhone: '5511988888888'),
      Order(id: '3', total: 50, status: OrderStatus.pending, createdAt: now, items: [], clientName: 'Carlos Santos', clientPhone: '5511977777777'),
      Order(id: '4', total: 300, status: OrderStatus.delivered, createdAt: now.subtract(const Duration(days: 2)), items: [], clientName: 'Ana Pereira', clientPhone: '5511966666666'),
      Order(id: '5', total: 500, status: OrderStatus.cancelled, createdAt: now.subtract(const Duration(days: 1)), items: [], clientName: 'Pedro Costa', clientPhone: '5511955555555'),
    ];
    
    for (final o in orders) {
      await repository.addOrder(o);
    }
    await refresh();
  }
}
