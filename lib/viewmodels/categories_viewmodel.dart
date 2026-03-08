import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/core/error/app_failure.dart';
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

  CategoryDeleteResult({
    required this.success,
    required this.hasProducts,
    this.message,
  });
}

@riverpod
class CategoriesViewModel extends _$CategoriesViewModel {
  @override
  FutureOr<CategoriesState> build() async {
    try {
      return await _fetchData();
    } catch (e) {
      throw e.toAppFailure(action: 'build', entity: 'Categories');
    }
  }

  Future<CategoriesState> _fetchData() async {
    final categoriesRepository = ref.watch(categoriesRepositoryProvider);
    final productRepository = ref.watch(productsRepositoryProvider);
    final allCategories = await categoriesRepository.getCategories();
    final allProducts = await productRepository.getProducts();

    // Count products
    final counts = <String, int>{};
    for (var c in allCategories) {
      counts[c.id] = allProducts
          .where((p) => p.categoryIds.contains(c.id))
          .length;
    }

    // Initial sort
    var sorted = List<Category>.from(allCategories);
    _applySort(sorted, CategorySortOption.manual);

    return CategoriesState(categories: sorted, productCounts: counts);
  }

  Future<void> _refresh() async {
    final hasData = state.value != null;
    if (!hasData) {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(() async {
      try {
        return await _fetchData();
      } catch (e) {
        throw e.toAppFailure(action: 'refresh', entity: 'Categories');
      }
    });
  }

  // Actions
  void setSearchQuery(String query) {
    if (state.value == null) return;
    final current = state.value!;
    state = AsyncData(
      CategoriesState(
        categories: current.categories,
        productCounts: current.productCounts,
        sortOption: current.sortOption,
        searchQuery: query,
      ),
    );
  }

  void setSortOption(CategorySortOption option) {
    if (state.value == null) return;
    final current = state.value!;
    final list = List<Category>.from(current.categories);
    _applySort(list, option);
    state = AsyncData(
      CategoriesState(
        categories: list,
        productCounts: current.productCounts,
        sortOption: option,
        searchQuery: current.searchQuery,
      ),
    );
  }

  void _applySort(List<Category> list, CategorySortOption option) {
    switch (option) {
      case CategorySortOption.manual:
        list.sort((a, b) => a.order.compareTo(b.order));
        break;
      case CategorySortOption.aToZ:
        list.sort(
          (a, b) =>
              a.safeName.toLowerCase().compareTo(b.safeName.toLowerCase()),
        );
        break;
      case CategorySortOption.zToA:
        list.sort(
          (a, b) =>
              b.safeName.toLowerCase().compareTo(a.safeName.toLowerCase()),
        );
        break;
    }
  }

  Future<String?> addCategory(
    String name,
    CategoryType type, {
    CollectionCover? cover,
    String? id,
  }) async {
    try {
      final categoriesRepo = ref.read(categoriesRepositoryProvider);
      final currentCategories = await categoriesRepo.getCategories();

      if (currentCategories.any(
        (c) =>
            c.safeName.trim().toLowerCase() == name.trim().toLowerCase() &&
            c.type == type,
      )) {
        return 'Categoria j\u00e1 existe';
      }

      final maxOrder = currentCategories.isNotEmpty
          ? currentCategories
                .map((c) => c.order)
                .reduce((a, b) => a > b ? a : b)
          : -1;

      final newCat = Category(
        id: id ?? const Uuid().v4(),
        name: name.trim(),
        order: maxOrder + 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        type: type,
        cover: cover,
        slug: Category.generateSlug(name),
      );

      await categoriesRepo.addCategory(newCat);
      await _refresh();
      ref.invalidate(productsViewModelProvider);
      return null;
    } catch (e) {
      throw e.toAppFailure(action: 'addCategory', entity: 'Category');
    }
  }

  Future<String?> addCollection({
    required String name,
    required String slug,
    required String coverMiniPath,
    String? coverPagePath,
    bool isActive = true,
    String? id,
  }) async {
    try {
      final categoriesRepo = ref.read(categoriesRepositoryProvider);
      final currentCategories = await categoriesRepo.getCategories();

      if (currentCategories.any(
        (c) =>
            c.type == CategoryType.collection &&
            c.safeSlug.trim().toLowerCase() == slug.trim().toLowerCase(),
      )) {
        return 'Slug j\u00e1 existe';
      }

      if (currentCategories.any(
        (c) =>
            c.type == CategoryType.collection &&
            c.safeName.trim().toLowerCase() == name.trim().toLowerCase(),
      )) {
        return 'Cole\u00e7\u00e3o j\u00e1 existe';
      }

      if (coverMiniPath.trim().isEmpty) {
        return 'Mini capa \u00e9 obrigat\u00f3ria';
      }

      final maxOrder = currentCategories.isNotEmpty
          ? currentCategories
                .map((c) => c.order)
                .reduce((a, b) => a > b ? a : b)
          : -1;

      final newCollection = Category(
        id: id ?? const Uuid().v4(),
        name: name.trim(),
        slug: slug.trim(),
        isActive: isActive,
        order: maxOrder + 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        type: CategoryType.collection,
        cover: CollectionCover(
          coverMiniPath: coverMiniPath,
          coverPagePath: coverPagePath,
        ),
      );

      await categoriesRepo.addCategory(newCollection);
      await _refresh();
      ref.invalidate(productsViewModelProvider);
      return null;
    } catch (e) {
      throw e.toAppFailure(action: 'addCollection', entity: 'Collection');
    }
  }

  Future<String?> updateCategory(
    String id,
    String newName, {
    CollectionCover? cover,
  }) async {
    try {
      final categoriesRepo = ref.read(categoriesRepositoryProvider);
      final currentCategories = await categoriesRepo.getCategories();

      if (currentCategories.any(
        (c) =>
            c.id != id &&
            c.safeName.trim().toLowerCase() == newName.trim().toLowerCase(),
      )) {
        return 'Nome j\u00e1 em uso';
      }

      final cat = currentCategories.firstWhere((c) => c.id == id);
      final updated = cat.copyWith(
        name: newName.trim(),
        updatedAt: DateTime.now(),
        cover: cover,
      );
      await categoriesRepo.updateCategory(updated);
      await _refresh();
      ref.invalidate(productsViewModelProvider);
      return null;
    } catch (e) {
      throw e.toAppFailure(action: 'updateCategory', entity: 'Category');
    }
  }

  Future<String?> updateCollection({
    required String id,
    required String name,
    required String slug,
    required String coverMiniPath,
    String? coverPagePath,
    required bool isActive,
  }) async {
    try {
      final categoriesRepo = ref.read(categoriesRepositoryProvider);
      final currentCategories = await categoriesRepo.getCategories();

      if (currentCategories.any(
        (c) =>
            c.id != id &&
            c.type == CategoryType.collection &&
            c.safeSlug.trim().toLowerCase() == slug.trim().toLowerCase(),
      )) {
        return 'Slug j\u00e1 existe';
      }

      if (coverMiniPath.trim().isEmpty) {
        return 'Mini capa \u00e9 obrigat\u00f3ria';
      }

      final cat = currentCategories.firstWhere((c) => c.id == id);
      final updated = cat.copyWith(
        name: name.trim(),
        slug: slug.trim(),
        isActive: isActive,
        updatedAt: DateTime.now(),
        cover: (cat.cover ?? const CollectionCover()).copyWith(
          coverMiniPath: coverMiniPath,
          coverPagePath: coverPagePath,
        ),
      );

      await categoriesRepo.updateCategory(updated);
      await _refresh();
      ref.invalidate(productsViewModelProvider);
      return null;
    } catch (e) {
      throw e.toAppFailure(action: 'updateCollection', entity: 'Collection');
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (state.value == null) return;
    if (state.value!.sortOption != CategorySortOption.manual) return;
    if (state.value!.searchQuery.isNotEmpty) return;

    final list = List<Category>.from(state.value!.categories);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    try {
      final categoriesRepo = ref.read(categoriesRepositoryProvider);
      for (var i = 0; i < list.length; i++) {
        final cat = list[i].copyWith(order: i);
        await categoriesRepo.updateCategory(cat);
      }

      state = AsyncData(
        CategoriesState(
          categories: list,
          productCounts: state.value!.productCounts,
          sortOption: CategorySortOption.manual,
          searchQuery: '',
        ),
      );
    } catch (e) {
      throw e.toAppFailure(action: 'reorder', entity: 'Categories');
    }
  }

  Future<CategoryDeleteResult> checkDelete(String id) async {
    try {
      final productRepository = ref.read(productsRepositoryProvider);
      final categoriesRepo = ref.read(categoriesRepositoryProvider);
      final products = await productRepository.getProductsByCategory(id);

      if (products.isEmpty) {
        await categoriesRepo.deleteCategory(id);
        await _refresh();
        ref.invalidate(productsViewModelProvider);
        return CategoryDeleteResult(success: true, hasProducts: false);
      } else {
        return CategoryDeleteResult(
          success: false,
          hasProducts: true,
          message: 'Existem ${products.length} produtos nesta categoria.',
        );
      }
    } catch (e) {
      throw e.toAppFailure(action: 'checkDelete', entity: 'Category');
    }
  }

  Future<void> deleteWithMove(String id, String targetCategoryId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final categoriesRepo = ref.read(categoriesRepositoryProvider);
        await categoriesRepo.reassignCategory(id, targetCategoryId);
        await categoriesRepo.deleteCategory(id);
        return await _fetchData();
      } catch (e) {
        throw e.toAppFailure(action: 'deleteWithMove', entity: 'Category');
      }
    });
  }

  Future<void> deleteAndUncategorize(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final categoriesRepo = ref.read(categoriesRepositoryProvider);
        await categoriesRepo.reassignCategory(id, '');
        await categoriesRepo.deleteCategory(id);
        return await _fetchData();
      } catch (e) {
        throw e.toAppFailure(
          action: 'deleteAndUncategorize',
          entity: 'Category',
        );
      }
    });
  }
}
