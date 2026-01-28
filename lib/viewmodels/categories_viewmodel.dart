import 'package:gravity/core/auth/auth_controller.dart';
import 'package:gravity/data/repositories/categories_repository.dart';
import 'package:gravity/data/repositories/products_repository.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/viewmodels/dashboard_viewmodel.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'categories_viewmodel.g.dart';

enum CategorySortOption { manual, aToZ, zToA }

class CategoriesState {
  final List<Category> categories;
  final Map<String, int> productCounts; // ID -> count
  final CategorySortOption sortOption;
  final String searchQuery;

  CategoriesState({
    required this.categories,
    required this.productCounts,
    this.sortOption = CategorySortOption.manual,
    this.searchQuery = '',
  });
}

class CategoryDeleteResult {
  final bool success;
  final bool hasProducts;
  final String? message;
  
  CategoryDeleteResult({required this.success, required this.hasProducts, this.message});
}

@riverpod
class CategoriesViewModel extends _$CategoriesViewModel {
  @override
  FutureOr<CategoriesState> build() async {
    return _fetchData();
  }

  Future<CategoriesState> _fetchData() async {
    final categoriesRepository = ref.watch(categoriesRepositoryProvider);
    final productRepository = ref.watch(productsRepositoryProvider);
    final allCategories = await categoriesRepository.getCategories();
    final allProducts = await productRepository.getProducts(); // optimization: get counts only if possible, but currently we fetch all
    
    // Count products
    final counts = <String, int>{};
    for (var c in allCategories) {
      counts[c.id] = allProducts.where((p) => p.categoryId == c.id).length;
    }
    
    // Initial sort
    var sorted = List<Category>.from(allCategories);
    _applySort(sorted, CategorySortOption.manual); // Default

    return CategoriesState(
      categories: sorted, 
      productCounts: counts,
    );
  }

  Future<void> _refresh() async {
     final hasData = state.value != null;
     if (!hasData) {
       state = const AsyncLoading();
     }
     state = await AsyncValue.guard(_fetchData);
  }

  // Actions
  void setSearchQuery(String query) {
     // Local filtering usually, but let's implement if needed. 
     // For now, let's keep it simple: Filter in UI or here? 
     // Requirement says: "Barra com busca". Let's update state and filter in UI or re-fetch.
     // Let's filter in logic to be consistent.
     if (state.value == null) return;
     final current = state.value!;
     
     // Note: If we just filter the list, we lose the "real" order for reordering.
     // Reordering usually requires the full list.
     // If search is active, disable reordering.
     
     state = AsyncData(CategoriesState(
       categories: current.categories, // We keep full list in "categories" for now? 
       // Actually, let's store filtered list in a separate field or just filter on the fly.
       // Let's assume the state holds the list to display. 
         // If search is empty, show all. If not, show filtered.
       productCounts: current.productCounts,
       sortOption: current.sortOption,
       searchQuery: query,
     ));
  }
  
  void setSortOption(CategorySortOption option) {
     if (state.value == null) return;
     final current = state.value!;
     final list = List<Category>.from(current.categories);
     _applySort(list, option);
     state = AsyncData(CategoriesState(
       categories: list,
       productCounts: current.productCounts,
       sortOption: option,
       searchQuery: current.searchQuery
     ));
  }

  void _applySort(List<Category> list, CategorySortOption option) {
    switch (option) {
      case CategorySortOption.manual:
        list.sort((a, b) => a.order.compareTo(b.order));
        break;
      case CategorySortOption.aToZ:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case CategorySortOption.zToA:
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
    }
  }

  Future<String?> addCategory(String name) async {
    _requireAdmin();
    final categoriesRepo = ref.read(categoriesRepositoryProvider);
    final currentCategories = await categoriesRepo.getCategories();
    
    // Check duplicate
    if (currentCategories.any((c) => c.name.trim().toLowerCase() == name.trim().toLowerCase())) {
      return 'Categoria já existe';
    }

    final maxOrder = currentCategories.isNotEmpty 
        ? currentCategories.map((c) => c.order).reduce((a, b) => a > b ? a : b) 
        : -1;

    final newCat = Category(
      id: const Uuid().v4(), 
      name: name.trim(), 
      order: maxOrder + 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await categoriesRepo.addCategory(newCat);
    await _refresh();
    
    // Notify other viewmodels that categories changed
    ref.invalidate(productsViewModelProvider);
    ref.invalidate(dashboardViewModelProvider);
    
    return null; // Success
  }

  Future<String?> updateCategory(String id, String newName) async {
    _requireAdmin();
    final categoriesRepo = ref.read(categoriesRepositoryProvider);
    final currentCategories = await categoriesRepo.getCategories();
    
    // Check duplicate (exclude self)
    if (currentCategories.any((c) => c.id != id && c.name.trim().toLowerCase() == newName.trim().toLowerCase())) {
       return 'Nome já em uso';
    }
    
    final cat = currentCategories.firstWhere((c) => c.id == id);
    final updated = cat.copyWith(name: newName.trim(), updatedAt: DateTime.now());
    await categoriesRepo.updateCategory(updated);
    await _refresh();
    
    // Notify other viewmodels
    ref.invalidate(productsViewModelProvider);
    ref.invalidate(dashboardViewModelProvider);
    
    return null;
  }
  
  // Reorder
  Future<void> reorder(int oldIndex, int newIndex) async {
     _requireAdmin();
     if (state.value == null) return;
     // Only allow in manual mode
     if (state.value!.sortOption != CategorySortOption.manual) return;
     
     // The list in state might be filtered. Reorder only works on full list roughly?
     // Assuming no filter for reorder.
     if (state.value!.searchQuery.isNotEmpty) return;

     final list = List<Category>.from(state.value!.categories);
     if (oldIndex < newIndex) {
       newIndex -= 1;
     }
     final item = list.removeAt(oldIndex);
     list.insert(newIndex, item);
     
     // Update orders in DB
     // Optimization: only update affected range? For now update all indexes for safety.
     final categoriesRepo = ref.read(categoriesRepositoryProvider);
     for (var i = 0; i < list.length; i++) {
        final cat = list[i].copyWith(order: i);
        if (cat.order != list[i].order) { // This check is dummy since we just updated logic
            // But we check DB diff? 
            // Just update all to be safe and simple.
        }
       await categoriesRepo.updateCategory(cat);
     }
     
     // Optimistic update
     state = AsyncData(CategoriesState(
       categories: list,
       productCounts: state.value!.productCounts,
       sortOption: CategorySortOption.manual,
       searchQuery: '',
     ));
  }

  // Delete Check
  Future<CategoryDeleteResult> checkDelete(String id) async {
     _requireAdmin();
     final productRepository = ref.read(productsRepositoryProvider);
     final categoriesRepo = ref.read(categoriesRepositoryProvider);
     final products = await productRepository.getProductsByCategory(id);
     
     if (products.isEmpty) {
       await categoriesRepo.deleteCategory(id);
       await _refresh();
       ref.invalidate(productsViewModelProvider);
       ref.invalidate(dashboardViewModelProvider);
       return CategoryDeleteResult(success: true, hasProducts: false);
     } else {
       return CategoryDeleteResult(success: false, hasProducts: true, message: 'Existem ${products.length} produtos nesta categoria.');
     }
  }
  
  // Confirm Delete
  // action: 'delete_products', 'move', 'uncategorize'
  // For requirement: 
  // b) Mover para "Sem Categoria" (create if not exists)
  // c) Definir null/uncategorized (essentially same as B if "Sem Categoria" is the concept of null)
  // Let's implement options directly.
  
  Future<void> deleteWithMove(String id, String targetCategoryId) async {
    _requireAdmin();
    final categoriesRepo = ref.read(categoriesRepositoryProvider);
     await categoriesRepo.reassignCategory(id, targetCategoryId);
     await categoriesRepo.deleteCategory(id);
     await _refresh();
  }
  
  Future<void> deleteAndUncategorize(String id) async {
     _requireAdmin();
     // Reassign to empty string or specialized 'uncategorized'
     final categoriesRepo = ref.read(categoriesRepositoryProvider);
     await categoriesRepo.reassignCategory(id, ''); // '' = Uncategorized
     await categoriesRepo.deleteCategory(id);
     await _refresh();
  }

  void _requireAdmin() {
    final user = ref.read(currentUserProvider);
    if (user == null || !user.isAdmin) {
      throw Exception('Sem permissão para modificar categorias.');
    }
  }
}
