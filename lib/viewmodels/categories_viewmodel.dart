import 'dart:async';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/firestore_categories_repository.dart';
import 'package:catalogo_ja/data/repositories/firestore_products_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/core/error/app_failure.dart';
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';
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
      // ✨ Garantia de SaaS: Se o usuário está logado, aguardamos o tenantId ser identificado
      // Isso evita que a tela comece "Vazia" usando o Repo Local enquanto o Firestore ainda carrega o perfil.
      final authUser = ref.watch(authViewModelProvider).valueOrNull;
      if (authUser != null) {
        await ref.watch(currentTenantProvider.future);
      }
      return await _fetchData();
    } catch (e) {
      throw e.toAppFailure(action: 'build', entity: 'Categories');
    }
  }

  Future<CategoriesState> _fetchData() async {
    final categoriesRepository = ref.watch(syncCategoriesRepositoryProvider);
    final productRepository = ref.watch(syncProductsRepositoryProvider);
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
      final categoriesRepo = ref.read(syncCategoriesRepositoryProvider);
      final currentCategories = await categoriesRepo.getCategories();

      if (currentCategories.any(
        (c) =>
            c.safeName.trim().toLowerCase() == name.trim().toLowerCase() &&
            c.type == type,
      )) {
        return 'Categoria já existe';
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
      final categoriesRepo = ref.read(syncCategoriesRepositoryProvider);
      final currentCategories = await categoriesRepo.getCategories();

      if (currentCategories.any(
        (c) =>
            c.type == CategoryType.collection &&
            c.safeSlug.trim().toLowerCase() == slug.trim().toLowerCase(),
      )) {
        return 'Slug já existe';
      }

      if (currentCategories.any(
        (c) =>
            c.type == CategoryType.collection &&
            c.safeName.trim().toLowerCase() == name.trim().toLowerCase(),
      )) {
        return 'Coleção já existe';
      }

      if (coverMiniPath.trim().isEmpty) {
        return 'Mini capa é obrigatória';
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
      final categoriesRepo = ref.read(syncCategoriesRepositoryProvider);
      final currentCategories = await categoriesRepo.getCategories();

      if (currentCategories.any(
        (c) =>
            c.id != id &&
            c.safeName.trim().toLowerCase() == newName.trim().toLowerCase(),
      )) {
        return 'Nome já em uso';
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
      final categoriesRepo = ref.read(syncCategoriesRepositoryProvider);
      final currentCategories = await categoriesRepo.getCategories();

      if (currentCategories.any(
        (c) =>
            c.id != id &&
            c.type == CategoryType.collection &&
            c.safeSlug.trim().toLowerCase() == slug.trim().toLowerCase(),
      )) {
        return 'Slug já existe';
      }

      if (coverMiniPath.trim().isEmpty) {
        return 'Mini capa é obrigatória';
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
      final categoriesRepo = ref.read(syncCategoriesRepositoryProvider);
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
      final productRepository = ref.read(syncProductsRepositoryProvider);
      final categoriesRepo = ref.read(syncCategoriesRepositoryProvider);
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
        final categoriesRepo = ref.read(syncCategoriesRepositoryProvider);
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
        final categoriesRepo = ref.read(syncCategoriesRepositoryProvider);
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

  /// Sincroniza todas as categorias/coleções locais para a nuvem
  Future<int> syncAllToCloud() async {
    final progressNotifier = ref.read(syncProgressProvider.notifier);
    try {
      progressNotifier.startSync('Iniciando sincronização de categorias...');
      
      final localRepo = ref.read(categoriesRepositoryProvider) as HiveCategoriesRepository;
      final localCategories = await localRepo.getCategories();
      
      if (localCategories.isEmpty) {
        progressNotifier.stopSync();
        return 0;
      }

      // Busca o tenantId
      final tenant = await ref.read(currentTenantProvider.future);
      String? tenantId = tenant?.id;
      if (tenantId == null) {
        final authUser = ref.read(authViewModelProvider).value;
        if (authUser?.email != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(authUser!.email!.toLowerCase().trim())
              .get();
          tenantId = userDoc.data()?['tenantId'] as String?;
        }
      }

      if (tenantId == null) {
        progressNotifier.stopSync();
        throw Exception('Empresa não identificada. Verifique seu login.');
      }
      
      final storageService = ref.read(saasPhotoStorageProvider);
      final firestoreRepo = FirestoreCategoriesRepository(localRepo, storageService, tenantId);
      var syncedCount = 0;
      final total = localCategories.length;

      for (var i = 0; i < total; i++) {
        final cat = localCategories[i];
        try {
          progressNotifier.updateProgress(
            (i + 1) / total,
            'Sincronizando: ${i + 1}/$total - ${cat.name}',
          );
          await firestoreRepo.addCategory(cat);
          syncedCount++;
        } catch (e) {
          print('❌ Erro ao sincronizar categoria ${cat.name}: $e');
        }
      }

      progressNotifier.stopSync();
      ref.invalidateSelf();
      return syncedCount;
    } catch (e) {
      progressNotifier.stopSync();
      print('Erro ao sincronizar categorias: $e');
      rethrow;
    }
  }

  /// Baixa todas as categorias/coleções da nuvem para o celular
  Future<int> syncFromCloud() async {
    final progressNotifier = ref.read(syncProgressProvider.notifier);
    try {
      progressNotifier.startSync('Buscando categorias na nuvem...');
      
      final tenant = await ref.read(currentTenantProvider.future);
      String? tenantId = tenant?.id;
      if (tenantId == null) {
        final authUser = ref.read(authViewModelProvider).value;
        if (authUser?.email != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(authUser!.email!.toLowerCase().trim())
              .get();
          tenantId = userDoc.data()?['tenantId'] as String?;
        }
      }

      if (tenantId == null) {
        progressNotifier.stopSync();
        throw Exception('Empresa não identificada.');
      }

      final storageService = ref.read(saasPhotoStorageProvider);
      final localRepo = ref.read(categoriesRepositoryProvider) as HiveCategoriesRepository;
      final firestoreRepo = FirestoreCategoriesRepository(localRepo, storageService, tenantId);

      final cloudCategories = await firestoreRepo.getCategories();
      if (cloudCategories.isEmpty) {
        progressNotifier.stopSync();
        return 0;
      }

      var downloadedCount = 0;
      final localCategories = await localRepo.getCategories();
      final localMap = {for (var c in localCategories) c.id: c};
      final total = cloudCategories.length;

      for (var i = 0; i < total; i++) {
        final cat = cloudCategories[i];
        final progress = (i + 1) / total;

        // 🚀 Verificação de Diferença (Sincronização Incremental/Inteligente)
        final localCat = localMap[cat.id];
        if (localCat != null && !cat.updatedAt.isAfter(localCat.updatedAt)) {
          // Já estamos atualizados localmente, pule para a próxima
          continue; 
        }

        try {
          progressNotifier.updateProgress(
            progress,
            'Baixando novidades: ${i + 1}/$total - ${cat.name}',
          );
          await localRepo.addCategory(cat);
          downloadedCount++;
        } catch (_) {}
      }

      progressNotifier.stopSync();
      await _refresh();
      return downloadedCount;
    } catch (e) {
      progressNotifier.stopSync();
      print('Erro ao baixar categorias: $e');
      rethrow;
    }
  }
}
