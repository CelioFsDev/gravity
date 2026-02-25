import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/viewmodels/catalog_public_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'products_viewmodel.g.dart';

enum ProductSort { recent, priceAsc, priceDesc, aToZ }

enum ProductStatusFilter {
  all,
  active,
  outOfStock,
  inactive,
  noPhotos,
  zeroPrice,
  createdToday,
} // Inactive not in logic yet but part of UI req

class ProductsState {
  final List<Product> allProducts;
  final List<Product> filteredProducts;
  final List<Category> categories;

  final String searchQuery;
  final String? collectionFilterId; // null = all
  final String? productTypeFilterId; // null = all
  final ProductStatusFilter statusFilter;
  final ProductSort sortOption;
  final Set<String> selectedProductIds;

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
    this.collectionFilterId,
    this.productTypeFilterId,
    this.statusFilter = ProductStatusFilter.all,
    this.sortOption = ProductSort.recent,
    this.selectedProductIds = const {},
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
    String? collectionFilterId,
    String? productTypeFilterId,
    ProductStatusFilter? statusFilter,
    ProductSort? sortOption,
    Set<String>? selectedProductIds,
    int? totalCount,
    int? activeCount,
    int? outOfStockCount,
    int? onSaleCount,
    bool forceNullCollection = false,
    bool forceNullProductType = false,
  }) {
    return ProductsState(
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      categories: categories ?? this.categories,
      searchQuery: searchQuery ?? this.searchQuery,
      collectionFilterId: forceNullCollection
          ? null
          : (collectionFilterId ?? this.collectionFilterId),
      productTypeFilterId: forceNullProductType
          ? null
          : (productTypeFilterId ?? this.productTypeFilterId),
      statusFilter: statusFilter ?? this.statusFilter,
      sortOption: sortOption ?? this.sortOption,
      selectedProductIds: selectedProductIds ?? this.selectedProductIds,
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
    final productRepository = ref.watch(productsRepositoryProvider);
    final categoryRepository = ref.watch(categoriesRepositoryProvider);
    final products = await productRepository.getProducts();
    final categories = await categoryRepository.getCategories();

    // Create initial state
    return _applyFilters(
      ProductsState.initial().copyWith(
        allProducts: products,
        categories: categories,
      ),
    );
  }

  // Actions
  void setSearchQuery(String query) {
    if (state.value == null) return;
    state = AsyncData(_applyFilters(state.value!.copyWith(searchQuery: query)));
  }

  void setCategoryFilter(String? categoryId) {
    if (state.value == null) return;
    state = AsyncData(
      _applyFilters(
        state.value!.copyWith(
          productTypeFilterId: categoryId,
          forceNullProductType: categoryId == null,
        ),
      ),
    );
  }

  void setCollectionFilter(String? collectionId) {
    if (state.value == null) return;
    state = AsyncData(
      _applyFilters(
        state.value!.copyWith(
          collectionFilterId: collectionId,
          forceNullCollection: collectionId == null,
        ),
      ),
    );
  }

  void setStatusFilter(ProductStatusFilter status) {
    if (state.value == null) return;
    state = AsyncData(
      _applyFilters(state.value!.copyWith(statusFilter: status)),
    );
  }

  void setSortOption(ProductSort sort) {
    if (state.value == null) return;
    state = AsyncData(_applyFilters(state.value!.copyWith(sortOption: sort)));
  }

  // Multi-selection Actions
  void toggleSelection(String productId) {
    if (state.value == null) return;
    final current = state.value!.selectedProductIds;
    final updated = Set<String>.from(current);
    if (updated.contains(productId)) {
      updated.remove(productId);
    } else {
      updated.add(productId);
    }
    state = AsyncData(state.value!.copyWith(selectedProductIds: updated));
  }

  void selectAll() {
    if (state.value == null) return;
    final allIds = state.value!.filteredProducts.map((p) => p.id).toSet();
    state = AsyncData(state.value!.copyWith(selectedProductIds: allIds));
  }

  void clearSelection() {
    if (state.value == null) return;
    state = AsyncData(state.value!.copyWith(selectedProductIds: {}));
  }

  Future<void> deleteSelected() async {
    if (state.value == null || state.value!.selectedProductIds.isEmpty) return;
    final repository = ref.read(productsRepositoryProvider);
    for (final id in state.value!.selectedProductIds) {
      await repository.deleteProduct(id);
    }
    await refresh();
    _notifyChanges();
  }

  Future<void> updateStatusSelected(bool active) async {
    if (state.value == null || state.value!.selectedProductIds.isEmpty) return;
    final repository = ref.read(productsRepositoryProvider);
    for (final id in state.value!.selectedProductIds) {
      final product = state.value!.allProducts.firstWhere((p) => p.id == id);
      await repository.updateProduct(product.copyWith(isActive: active));
    }
    await refresh();
    _notifyChanges();
  }

  Future<void> updateCategorySelected(String categoryId) async {
    if (state.value == null || state.value!.selectedProductIds.isEmpty) return;
    final repository = ref.read(productsRepositoryProvider);
    for (final id in state.value!.selectedProductIds) {
      final product = state.value!.allProducts.firstWhere((p) => p.id == id);
      // Logic: replace or toggle? Let's say we replace/add it.
      // If product already has this category, do nothing. Else add.
      if (!product.categoryIds.contains(categoryId)) {
        final updatedIds = List<String>.from(product.categoryIds)
          ..add(categoryId);
        await repository.updateProduct(
          product.copyWith(categoryIds: updatedIds),
        );
      }
    }
    await refresh();
    _notifyChanges();
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
  }

  Future<void> refresh() async {
    final previous = state.value ?? ProductsState.initial();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(productsRepositoryProvider);
      final categoriesRepository = ref.read(categoriesRepositoryProvider);
      final products = await repository.getProducts();
      final categories = await categoriesRepository.getCategories();
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
    if (currentState.collectionFilterId != null) {
      filtered = filtered
          .where((p) => p.categoryIds.contains(currentState.collectionFilterId))
          .toList();
    }
    if (currentState.productTypeFilterId != null) {
      filtered = filtered
          .where(
            (p) => p.categoryIds.contains(currentState.productTypeFilterId),
          )
          .toList();
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
      case ProductStatusFilter.noPhotos:
        filtered = filtered.where((p) => p.images.isEmpty).toList();
        break;
      case ProductStatusFilter.zeroPrice:
        filtered = filtered.where((p) => p.retailPrice <= 0).toList();
        break;
      case ProductStatusFilter.createdToday:
        final now = DateTime.now();
        filtered = filtered.where((p) {
          return p.createdAt.year == now.year &&
              p.createdAt.month == now.month &&
              p.createdAt.day == now.day;
        }).toList();
        break;
      case ProductStatusFilter.all:
        break;
    }

    // 4. Sort
    filtered.sort((a, b) {
      switch (currentState.sortOption) {
        case ProductSort.recent:
          return b.createdAt.compareTo(a.createdAt);
        case ProductSort.priceAsc:
          return a.retailPrice.compareTo(b.retailPrice);
        case ProductSort.priceDesc:
          return b.retailPrice.compareTo(a.retailPrice);
        case ProductSort.aToZ:
          return a.name.compareTo(b.name);
      }
    });

    // Calc KPIs (Always based on allProducts)
    final total = currentState.allProducts.length;
    final active = currentState.allProducts.where((p) => p.isActive).length;
    final outOfStock = currentState.allProducts
        .where((p) => p.isOutOfStock)
        .length;
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
