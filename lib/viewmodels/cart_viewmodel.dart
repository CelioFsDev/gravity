import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/models/order.dart';

class CartState {
  final String tenantId;
  final String catalogId;
  final List<OrderItem> items;

  CartState({
    required this.tenantId,
    required this.catalogId,
    this.items = const [],
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({
    String? tenantId,
    String? catalogId,
    List<OrderItem>? items,
  }) {
    return CartState(
      tenantId: tenantId ?? this.tenantId,
      catalogId: catalogId ?? this.catalogId,
      items: items ?? this.items,
    );
  }
}

class CartViewModel extends StateNotifier<CartState> {
  CartViewModel() : super(CartState(tenantId: '', catalogId: ''));

  void initCart(String tenantId, String catalogId) {
    if (state.catalogId != catalogId) {
      state = CartState(tenantId: tenantId, catalogId: catalogId);
      return;
    }
    state = state.copyWith(tenantId: tenantId, catalogId: catalogId);
  }

  void addItem(OrderItem item) {
    // Procura se já existe um item idêntico no carrinho (mesma grade/cor/sku)
    final existingIndex = state.items.indexWhere(
      (i) =>
          i.productId == item.productId &&
          i.sku == item.sku &&
          _compareAttributes(i.attributes, item.attributes),
    );

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updatedItem = OrderItem(
        productId: existing.productId,
        productName: existing.productName,
        sku: existing.sku,
        quantity: existing.quantity + item.quantity,
        unitPrice: existing.unitPrice,
        attributes: existing.attributes,
        notes: existing.notes,
      );

      final newItems = List<OrderItem>.from(state.items);
      newItems[existingIndex] = updatedItem;
      state = state.copyWith(items: newItems);
    } else {
      state = state.copyWith(items: [...state.items, item]);
    }
  }

  void removeItem(int index) {
    final newItems = List<OrderItem>.from(state.items);
    newItems.removeAt(index);
    state = state.copyWith(items: newItems);
  }

  void updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(index);
      return;
    }

    final existing = state.items[index];
    final updatedItem = OrderItem(
      productId: existing.productId,
      productName: existing.productName,
      sku: existing.sku,
      quantity: newQuantity,
      unitPrice: existing.unitPrice,
      attributes: existing.attributes,
      notes: existing.notes,
    );

    final newItems = List<OrderItem>.from(state.items);
    newItems[index] = updatedItem;
    state = state.copyWith(items: newItems);
  }

  void updateItem(int index, OrderItem item) {
    if (index < 0 || index >= state.items.length) return;
    if (item.quantity <= 0) {
      removeItem(index);
      return;
    }

    final newItems = List<OrderItem>.from(state.items);
    newItems[index] = item;
    state = state.copyWith(items: newItems);
  }

  void clearCart() {
    state = state.copyWith(items: []);
  }

  /// Gera a entidade final do Pedido baseada no carrinho
  Order generateOrder({
    required String customerName,
    required String customerPhone,
    double discount = 0.0,
    double shippingCost = 0.0,
  }) {
    if (state.items.isEmpty) {
      throw Exception('O carrinho está vazio');
    }

    return Order(
      tenantId: state.tenantId,
      catalogId: state.catalogId,
      customerName: customerName,
      customerPhone: customerPhone,
      items: List.from(state.items),
      status: OrderStatus.pending,
      discount: discount,
      shippingCost: shippingCost,
    );
  }

  bool _compareAttributes(Map<String, String>? a, Map<String, String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

final cartViewModelProvider = StateNotifierProvider<CartViewModel, CartState>((
  ref,
) {
  return CartViewModel();
});
