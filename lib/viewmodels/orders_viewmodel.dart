import 'package:flutter/material.dart';
import 'package:gravity/data/repositories/orders_repository.dart';
import 'package:gravity/models/order.dart';
import 'package:gravity/models/order_status.dart';
import 'package:gravity/viewmodels/dashboard_viewmodel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'orders_viewmodel.g.dart';

enum SortOption { recent, oldest, highValue }

class OrdersState {
  final List<Order> allOrders;
  final List<Order> filteredOrders;
  final OrderStatus? filterStatus; // null means All
  final String searchQuery;
  final DateTimeRange? dateRange;
  final SortOption sortOption;

  OrdersState({
    required this.allOrders,
    required this.filteredOrders,
    this.filterStatus,
    this.searchQuery = '',
    this.dateRange,
    this.sortOption = SortOption.recent,
  });

  OrdersState copyWith({
    List<Order>? allOrders,
    List<Order>? filteredOrders,
    OrderStatus? filterStatus,
    String? searchQuery,
    DateTimeRange? dateRange,
    SortOption? sortOption,
    bool forceNullStatus = false, // Helper to set status to null
  }) {
    return OrdersState(
      allOrders: allOrders ?? this.allOrders,
      filteredOrders: filteredOrders ?? this.filteredOrders,
      filterStatus: forceNullStatus ? null : (filterStatus ?? this.filterStatus),
      searchQuery: searchQuery ?? this.searchQuery,
      dateRange: dateRange ?? this.dateRange,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

@riverpod
class OrdersViewModel extends _$OrdersViewModel {
  @override
  FutureOr<OrdersState> build() async {
    final repository = ref.watch(ordersRepositoryProvider);
    final orders = await repository.getOrders();
    // Initial state: all orders, filtered = all (sorted by recent)
    return _applyFilters(
      OrdersState(
        allOrders: orders,
        filteredOrders: [], // will be set by _applyFilters
      ),
    );
  }

  void setFilterStatus(OrderStatus? status) {
    if (state.value == null) return;
    final currentState = state.value!;
    
    // Logic: if clicking the same status, toggle off? User usually wants explicit "All" button.
    // Assuming UI passes null for "All".
    state = AsyncData(_applyFilters(currentState.copyWith(
      filterStatus: status,
      forceNullStatus: status == null,
    )));
  }

  void setSearchQuery(String query) {
    if (state.value == null) return;
    state = AsyncData(_applyFilters(state.value!.copyWith(searchQuery: query)));
  }

  void setDateRange(DateTimeRange? range) {
    if (state.value == null) return;
    state = AsyncData(_applyFilters(state.value!.copyWith(dateRange: range)));
  }

  void setSortOption(SortOption option) {
    if (state.value == null) return;
    state = AsyncData(_applyFilters(state.value!.copyWith(sortOption: option)));
  }

  Future<void> updateStatus(String orderId, OrderStatus newStatus) async {
    // Optimistic update? Better to await repo.
    final repository = ref.read(ordersRepositoryProvider);
    final currentOrders = state.value?.allOrders ?? [];
    
    final index = currentOrders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    final updatedOrder = currentOrders[index].copyWith(status: newStatus);
    await repository.addOrder(updatedOrder); // Hive put updates if ID exists

    // Refresh data
    // Option A: Reload from repo. Option B: Update local list.
    // Let's reload to be safe and consistent.
    final newOrders = await repository.getOrders();
    state = AsyncData(_applyFilters(state.value!.copyWith(allOrders: newOrders)));
    
    // Notify dashboard that order status changed
    ref.invalidate(dashboardViewModelProvider);
  }

  OrdersState _applyFilters(OrdersState currentState) {
    List<Order> filtered = List.of(currentState.allOrders);

    // 1. Status Filter
    if (currentState.filterStatus != null) {
      filtered = filtered.where((o) => o.status == currentState.filterStatus).toList();
    }

    // 2. Search Filter (ID, Client Name, Whatsapp)
    if (currentState.searchQuery.isNotEmpty) {
      final query = currentState.searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        return o.id.toLowerCase().contains(query) ||
               o.clientName.toLowerCase().contains(query) ||
               o.clientPhone.contains(query);
      }).toList();
    }

    // 3. Date Range Filter
    if (currentState.dateRange != null) {
      final start = currentState.dateRange!.start;
      final end = currentState.dateRange!.end.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)); // End of day
      filtered = filtered.where((o) => o.createdAt.isAfter(start) && o.createdAt.isBefore(end)).toList();
    }

    // 4. Sorting
    filtered.sort((a, b) {
      switch (currentState.sortOption) {
        case SortOption.recent:
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.oldest:
          return a.createdAt.compareTo(b.createdAt);
        case SortOption.highValue:
          return b.total.compareTo(a.total);
      }
    });

    return currentState.copyWith(filteredOrders: filtered);
  }
}
