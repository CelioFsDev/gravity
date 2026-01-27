
import 'package:gravity/data/repositories/products_repository.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/viewmodels/catalog_public_viewmodel.dart';
import 'package:gravity/viewmodels/catalogs_viewmodel.dart';
import 'package:gravity/viewmodels/categories_viewmodel.dart';
import 'package:gravity/viewmodels/dashboard_viewmodel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'products_viewmodel.g.dart';

enum ProductSort { recent, priceAsc, priceDesc, aToZ }
enum ProductStatusFilter { all, active, outOfStock, inactive } // Inactive not in logic yet but part of UI req

class ProductsState {
  final List<Product> allProducts;
  final List<Product> filteredProducts;
  final List<Category> categories;
  
  final String searchQuery;
  final String? categoryFilterId; // null = all
  final ProductStatusFilter statusFilter;
  final ProductSort sortOption;

  // KPIs
  final int totalCount;
  final int activeCount;
  final int outOfStockCount;
  final int onSaleCount;

  ProductsState({
    required this.allProducts,
    required this.filteredProducts,
    required this.categories,
    this.searchQuery = '',
    this.categoryFilterId,
    this.statusFilter = ProductStatusFilter.all,
    this.sortOption = ProductSort.recent,
    required this.totalCount,
    required this.activeCount,
    required this.outOfStockCount,
    required this.onSaleCount,
  });

  factory ProductsState.initial() {
    return ProductsState(
      allProducts: [],
      filteredProducts: [],
      categories: [],
      totalCount: 0,
      activeCount: 0,
      outOfStockCount: 0,
      onSaleCount: 0,
    );
  }

  ProductsState copyWith({
    List<Product>? allProducts,
    List<Product>? filteredProducts,
    List<Category>? categories,
    String? searchQuery,
    String? categoryFilterId,
    ProductStatusFilter? statusFilter,
    ProductSort? sortOption,
    int? totalCount,
    int? activeCount,
    int? outOfStockCount,
    int? onSaleCount,
    bool forceNullCategory = false,
  }) {
    return ProductsState(
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      categories: categories ?? this.categories,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilterId: forceNullCategory ? null : (categoryFilterId ?? this.categoryFilterId),
      statusFilter: statusFilter ?? this.statusFilter,
      sortOption: sortOption ?? this.sortOption,
      totalCount: totalCount ?? this.totalCount,
      activeCount: activeCount ?? this.activeCount,
      outOfStockCount: outOfStockCount ?? this.outOfStockCount,
      onSaleCount: onSaleCount ?? this.onSaleCount,
    );
  }
}

@riverpod
class ProductsViewModel extends _$ProductsViewModel {
  @override
  FutureOr<ProductsState> build() async {
    final repository = ref.watch(productsRepositoryProvider);
    final products = await repository.getProducts();
    final categories = await repository.getCategories();
    
    // Create initial state
    return _applyFilters(ProductsState.initial().copyWith(
      allProducts: products,
      categories: categories,
    ));
  }

  // Actions
  void setSearchQuery(String query) {
     if (state.value == null) return;
     state = AsyncData(_applyFilters(state.value!.copyWith(searchQuery: query)));
  }
  
  void setCategoryFilter(String? categoryId) {
    if (state.value == null) return;
    state = AsyncData(_applyFilters(state.value!.copyWith(
      categoryFilterId: categoryId,
      forceNullCategory: categoryId == null,
    )));
  }

  void setStatusFilter(ProductStatusFilter status) {
    if (state.value == null) return;
    state = AsyncData(_applyFilters(state.value!.copyWith(statusFilter: status)));
  }

  void setSortOption(ProductSort sort) {
    if (state.value == null) return;
    state = AsyncData(_applyFilters(state.value!.copyWith(sortOption: sort)));
  }

  Future<void> deleteProduct(String id) async {
    final repository = ref.read(productsRepositoryProvider);
    await repository.deleteProduct(id);
    await refresh();
    _notifyChanges();
  }
  
  Future<void> addProduct(Product product) async {
    final repository = ref.read(productsRepositoryProvider);
    await repository.addProduct(product);
    await refresh();
    _notifyChanges();
  }
  
  Future<void> updateProduct(Product product) async {
    final repository = ref.read(productsRepositoryProvider);
    await repository.updateProduct(product);
    await refresh();
    _notifyChanges();
  }
  
  void _notifyChanges() {
    // Notify other viewmodels that products changed
    ref.invalidate(categoriesViewModelProvider);
    ref.invalidate(catalogsViewModelProvider);
    ref.invalidate(catalogPublicProvider);
    ref.invalidate(dashboardViewModelProvider);
  }
  


  Future<void> refresh() async {
    final previous = state.value ?? ProductsState.initial();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(productsRepositoryProvider);
      final products = await repository.getProducts();
      final categories = await repository.getCategories();
      final updated = previous.copyWith(
        allProducts: products,
        categories: categories,
      );
      return _applyFilters(updated);
    });
  }

  // Internal Logic
  ProductsState _applyFilters(ProductsState currentState) {
    List<Product> filtered = List.of(currentState.allProducts);

    // 1. Search Query
    if (currentState.searchQuery.isNotEmpty) {
      final q = currentState.searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(q) ||
               p.reference.toLowerCase().contains(q) ||
               p.sku.toLowerCase().contains(q) || 
               p.colors.any((c) => c.toLowerCase().contains(q));
      }).toList();
    }

    // 2. Category
    if (currentState.categoryFilterId != null) {
      filtered = filtered.where((p) => p.categoryId == currentState.categoryFilterId).toList();
    }

    // 3. Status
    switch (currentState.statusFilter) {
      case ProductStatusFilter.active:
        filtered = filtered.where((p) => p.isActive).toList();
        break;
      case ProductStatusFilter.outOfStock:
        filtered = filtered.where((p) => p.isOutOfStock).toList();
        break;
      case ProductStatusFilter.inactive:
         filtered = filtered.where((p) => !p.isActive).toList();
         break;
      case ProductStatusFilter.all:
        break;
    }

    // 4. Sort
    filtered.sort((a, b) {
       switch (currentState.sortOption) {
         case ProductSort.recent: return b.createdAt.compareTo(a.createdAt);
         case ProductSort.priceAsc: return a.retailPrice.compareTo(b.retailPrice);
         case ProductSort.priceDesc: return b.retailPrice.compareTo(a.retailPrice);
         case ProductSort.aToZ: return a.name.compareTo(b.name);
       }
    });

    // Calc KPIs (Always based on allProducts)
    final total = currentState.allProducts.length;
    final active = currentState.allProducts.where((p) => p.isActive).length;
    final outOfStock = currentState.allProducts.where((p) => p.isOutOfStock).length;
    final onSale = currentState.allProducts.where((p) => p.isOnSale).length;

    return currentState.copyWith(
      filteredProducts: filtered,
      totalCount: total,
      activeCount: active,
      outOfStockCount: outOfStock,
      onSaleCount: onSale,
    );
  }
}
