import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/order_item.dart';
import 'package:gravity/models/product.dart';

// State: List of items
class CartState {
  final List<OrderItem> items;
  
  CartState({this.items = const []});
  
  double get total => items.fold(0, (sum, item) => sum + item.total);
}

class CartViewModel extends StateNotifier<CartState> {
  CartViewModel() : super(CartState());

  void addToCart(Product product, int quantity, String? selectedSize, double unitPrice) {
    // Check if item exists (same product AND same size)
    final existingIndex = state.items.indexWhere((i) => i.productId == product.id && i.selectedSize == selectedSize);

    if (existingIndex >= 0) {
      // Update quantity
      final existing = state.items[existingIndex];
      final newQuantity = existing.quantity + quantity;
      
      final updatedItem = existing.copyWith(
          quantity: newQuantity, 
          total: newQuantity * existing.unitPrice
      );
      
      final newItems = List<OrderItem>.from(state.items);
      newItems[existingIndex] = updatedItem;
      state = CartState(items: newItems);
    } else {
      // Add new
      final newItem = OrderItem(
        productId: product.id,
        productName: product.name,
        productReference: product.reference,
        quantity: quantity,
        unitPrice: unitPrice,
        total: unitPrice * quantity,
        selectedSize: selectedSize,
        // Color not selected for now as per prompt "seleção de tamanho (se houver)"
      );
      state = CartState(items: [...state.items, newItem]);
    }
  }

  void removeFromCart(int index) {
      final newItems = List<OrderItem>.from(state.items)..removeAt(index);
      state = CartState(items: newItems);
  }

  void updateQuantity(int index, int delta) {
    // Delta can be +1 or -1
    final item = state.items[index];
    final newQty = item.quantity + delta;
    
    if (newQty <= 0) {
      removeFromCart(index);
      return;
    }
    
    final updatedItem = item.copyWith(
      quantity: newQty,
      total: newQty * item.unitPrice,
    );
    
    final newItems = List<OrderItem>.from(state.items);
    newItems[index] = updatedItem;
    state = CartState(items: newItems);
  }
  
  void clear() {
    state = CartState(items: []);
  }
}

// Global provider for cart (session scoped basically)
final cartViewModelProvider = StateNotifierProvider<CartViewModel, CartState>((ref) => CartViewModel());
