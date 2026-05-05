import 'package:catalogo_ja/core/sync/providers/sync_providers.dart';
import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/data/repositories/tenant_repository.dart';
import 'package:catalogo_ja/data/repositories/firestore_products_repository.dart';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:catalogo_ja/core/services/photo_classification_service.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:catalogo_ja/viewmodels/catalog_public_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/core/error/app_failure.dart';
import 'package:catalogo_ja/core/services/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';

part 'products_viewmodel.g.dart';

enum ProductSort { recent, priceAsc, priceDesc, aToZ }

enum ProductStatusFilter {
  all,
  active,
  outOfStock,
  inactive,
  withPhotos,
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

class SyncProgress {
  final double progress;
  final String message;
  final bool isSyncing;

  SyncProgress({
    this.progress = 0.0,
    this.message = '',
    this.isSyncing = false,
  });

  SyncProgress copyWith({double? progress, String? message, bool? isSyncing}) {
    return SyncProgress(
      progress: progress ?? this.progress,
      message: message ?? this.message,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

class SyncProgressNotifier extends StateNotifier<SyncProgress> {
  SyncProgressNotifier() : super(SyncProgress());

  void startSync(String message) {
    state = SyncProgress(isSyncing: true, progress: 0.0, message: message);
  }

  void updateProgress(double progress, String message) {
    state = state.copyWith(progress: progress, message: message);
  }

  void stopSync({String? message}) {
    state = SyncProgress(
      isSyncing: false,
      progress: 1.0,
      message: message ?? '',
    );
  }

  void reset() {
    state = SyncProgress();
  }
}

final syncProgressProvider =
    StateNotifierProvider<SyncProgressNotifier, SyncProgress>(
      (ref) => SyncProgressNotifier(),
    );

final cloudProductUpdatesPendingProvider = StreamProvider.autoDispose<bool>((
  ref,
) {
  final tenant = ref.watch(currentTenantProvider).valueOrNull;
  final state = ref.watch(productsViewModelProvider).valueOrNull;
  final settings = ref.watch(settingsRepositoryProvider).getSettings();

  if (tenant == null || settings.localOnlyMode || state == null) {
    return Stream<bool>.value(false);
  }

  if (state.allProducts.isEmpty && !settings.isInitialSyncCompleted) {
    return Stream<bool>.value(false);
  }

  Query<Map<String, dynamic>> query = FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenant.id)
      .collection('products');

  if (state.allProducts.isNotEmpty) {
    final mostRecentLocal = state.allProducts
        .map((p) => p.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    query = query.where(
      'updatedAt',
      isGreaterThan: mostRecentLocal.toIso8601String(),
    );
  }

  return query.limit(1).snapshots().map((snapshot) => snapshot.docs.isNotEmpty);
});

@riverpod
class ProductsViewModel extends _$ProductsViewModel {
  @override
  FutureOr<ProductsState> build() async {
    try {
      // ✨ Garantia de SaaS: Se o usuário está logado, aguardamos o tenantId ser identificado
      final authUser = ref.watch(authViewModelProvider).valueOrNull;
      if (authUser != null) {
        await ref.watch(currentTenantProvider.future);
      }

      final productRepository = ref.watch(syncProductsRepositoryProvider);
      final categoryRepository = ref.watch(categoriesRepositoryProvider);
      final products = await productRepository.getProducts();
      final categories = await categoryRepository.getCategories();

      return _applyFilters(
        ProductsState.initial().copyWith(
          allProducts: products,
          categories: categories,
        ),
      );
    } catch (e) {
      throw e.toAppFailure(action: 'build', entity: 'Products');
    }
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(syncProductsRepositoryProvider);
        for (final id in state.value!.selectedProductIds) {
          await repository.deleteProduct(id);
        }
        await refresh();
        _notifyChanges();
        return state.value!;
      } catch (e) {
        throw e.toAppFailure(action: 'deleteSelected', entity: 'Products');
      }
    });
  }

  Future<void> updateStatusSelected(bool active) async {
    if (state.value == null || state.value!.selectedProductIds.isEmpty) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(syncProductsRepositoryProvider);
        for (final id in state.value!.selectedProductIds) {
          final product = state.value!.allProducts.firstWhere(
            (p) => p.id == id,
          );
          await repository.updateProduct(product.copyWith(isActive: active));
        }
        await refresh();
        _notifyChanges();
        return state.value!;
      } catch (e) {
        throw e.toAppFailure(
          action: 'updateStatusSelected',
          entity: 'Products',
        );
      }
    });
  }

  Future<void> updateCategorySelected(String categoryId) async {
    if (state.value == null || state.value!.selectedProductIds.isEmpty) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(syncProductsRepositoryProvider);
        for (final id in state.value!.selectedProductIds) {
          final product = state.value!.allProducts.firstWhere(
            (p) => p.id == id,
          );
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
        return state.value!;
      } catch (e) {
        throw e.toAppFailure(
          action: 'updateCategorySelected',
          entity: 'Products',
        );
      }
    });
  }

  Future<void> addCategoriesToSelected(Iterable<String> categoryIds) async {
    if (state.value == null || state.value!.selectedProductIds.isEmpty) return;
    final idsToAdd = categoryIds.where((id) => id.trim().isNotEmpty).toSet();
    if (idsToAdd.isEmpty) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(syncProductsRepositoryProvider);
        for (final id in state.value!.selectedProductIds) {
          final product = state.value!.allProducts.firstWhere(
            (p) => p.id == id,
          );
          final updatedIds = {...product.categoryIds, ...idsToAdd}.toList();
          await repository.updateProduct(
            product.copyWith(categoryIds: updatedIds),
          );
        }
        await refresh();
        _notifyChanges();
        return state.value!;
      } catch (e) {
        throw e.toAppFailure(
          action: 'addCategoriesToSelected',
          entity: 'Products',
        );
      }
    });
  }

  Future<void> clearCategoriesSelected() async {
    if (state.value == null || state.value!.selectedProductIds.isEmpty) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(syncProductsRepositoryProvider);
        for (final id in state.value!.selectedProductIds) {
          final product = state.value!.allProducts.firstWhere(
            (p) => p.id == id,
          );
          await repository.updateProduct(
            product.copyWith(categoryIds: const []),
          );
        }
        await refresh();
        _notifyChanges();
        return state.value!;
      } catch (e) {
        throw e.toAppFailure(
          action: 'clearCategoriesSelected',
          entity: 'Products',
        );
      }
    });
  }

  Future<void> deleteProduct(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(syncProductsRepositoryProvider);
        await repository.deleteProduct(id);

        _notifyChanges();
        ref
            .read(appLoggerProvider.notifier)
            .log(AppEvent.productDeleted, parameters: {'productId': id});
        return await build();
      } catch (e) {
        throw e.toAppFailure(action: 'deleteProduct', entity: 'Product');
      }
    });
  }

  Future<void> addProduct(Product product) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 🏠 Local-First: Salva apenas localmente (Hive).
      final repository = ref.read(syncProductsRepositoryProvider);
      await repository.addProduct(product);

      _notifyChanges();
      ref
          .read(appLoggerProvider.notifier)
          .log(
            AppEvent.productCreated,
            parameters: {'productId': product.id, 'name': product.name},
          );

      return await build();
    });
  }

  Future<void> updateProduct(Product product) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 🏠 Local-First: Atualiza apenas o Hive.
      final repository = ref.read(syncProductsRepositoryProvider);
      await repository.updateProduct(product);

      _notifyChanges();
      ref
          .read(appLoggerProvider.notifier)
          .log(AppEvent.productUpdated, parameters: {'productId': product.id});

      return await build();
    });
  }

  Future<void> updateProductsBulk(List<Product> products) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (kIsWeb) {
        final cloudRepository = ref.read(syncProductsRepositoryProvider);
        final progressNotifier = ref.read(syncProgressProvider.notifier);

        progressNotifier.startSync('Atualizando lote na nuvem (Web)...');
        await cloudRepository.updateProductsBulk(
          products,
          onProgress: (p, m) => progressNotifier.updateProgress(p, m),
        );
        progressNotifier.stopSync();
      } else {
        final cloudRepository = ref.read(syncProductsRepositoryProvider);
        await cloudRepository.updateProductsBulk(products);
      }

      _notifyChanges();
      ref
          .read(appLoggerProvider.notifier)
          .log(
            AppEvent.productUpdated,
            parameters: {'bulkCount': products.length},
          );

      return await build();
    });
  }

  Future<int> syncAllToCloud() async {
    final progressNotifier = ref.read(syncProgressProvider.notifier);
    progressNotifier.startSync('Iniciando sincronização...');

    try {
      // 1. Primeiro sincroniza Categorias/Coleções (importante para integridade)
      final categoriesNotifier = ref.read(categoriesViewModelProvider.notifier);
      await categoriesNotifier.syncAllToCloud();

      // 2. Depois sincroniza Produtos
      final repository = ref.read(syncProductsRepositoryProvider);

      if (repository is FirestoreProductsRepository) {
        final count = await repository.syncAllPending(
          onProgress: (p, m) => progressNotifier.updateProgress(p, m),
        );
        progressNotifier.stopSync(
          message: 'Sincronização concluída: $count produtos atualizados.',
        );
        await refresh();
        _notifyChanges();
        return count;
      }

      return 0;
    } catch (e) {
      progressNotifier.stopSync(message: 'Erro na sincronização: $e');
      debugPrint('Erro na sincronização: $e');
      rethrow;
    }
  }

  /// Baixa todos os produtos da nuvem para o celular local
  Future<int> syncFromCloud() async {
    final progressNotifier = ref.read(syncProgressProvider.notifier);
    progressNotifier.startSync('Buscando produtos na nuvem...');

    try {
      final tenant = await ref.read(currentTenantProvider.future);
      String? tenantId = tenant?.id;

      // Fallback para o documento do usuário
      if (tenantId == null) {
        final email = ref.read(authViewModelProvider).valueOrNull?.email;
        if (email != null) {
          tenantId = await ref
              .read(tenantRepositoryProvider)
              .getCachedTenantId(email);
        }
      }

      if (tenantId == null || tenantId.isEmpty) {
        throw Exception(
          'Você precisa estar logado em uma empresa para baixar os dados.',
        );
      }

      // 1. Pega os repositórios e serviços

      final localRepo =
          ref.read(productsRepositoryProvider) as HiveProductsRepository;
      final storageService = ref.read(saasPhotoStorageProvider);
      final firestoreRepo = FirestoreProductsRepository(
        localRepo,
        storageService,
        tenantId,
        ref.read(syncQueueRepositoryProvider),
      );

      // 2. Busca inicial
      final currentLocalProducts = await localRepo.getProducts();

      // 3. Trava de Offline-First (Exigência de ZIP na carga inicial)
      if (currentLocalProducts.isEmpty) {
        final settings = ref.read(settingsRepositoryProvider).getSettings();
        if (!settings.isInitialSyncCompleted) {
          progressNotifier.stopSync(
            message:
                'Carga inicial pendente. Use a opção de importar backup via WinRAR (ZIP).',
          );
          return 0; // Abort download to save Firebase reads
        }
      }

      // 4. Busca na Nuvem (apenas novidades)
      debugPrint('Buscando produtos na nuvem...');
      final localMap = {for (var p in currentLocalProducts) p.id: p};
      DateTime? mostRecentLocal;
      if (currentLocalProducts.isNotEmpty) {
        mostRecentLocal = currentLocalProducts
            .map((p) => p.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      final cloudProducts = await firestoreRepo.fetchFromCloudOnly(
        since: mostRecentLocal,
      );

      if (cloudProducts.isEmpty) {
        progressNotifier.stopSync(message: 'Tudo atualizado!');
        return 0;
      }

      int updateCount = 0;
      for (var i = 0; i < cloudProducts.length; i++) {
        final p = cloudProducts[i];
        progressNotifier.updateProgress(
          (i + 1) / cloudProducts.length,
          'Baixando ${i + 1}/${cloudProducts.length}: ${p.name}',
        );

        final localProduct = localMap[p.id];
        // Se já existe localmente e não é mais novo que o local, ignora
        if (localProduct != null &&
            !p.updatedAt.isAfter(localProduct.updatedAt)) {
          continue;
        }

        // Se o local está pendente de upload, evitamos sobreescrever sem aviso (simples merge for cloud)
        if (localProduct != null &&
            localProduct.syncStatus == SyncStatus.pendingUpdate) {
          // Em caso de conflito, poderíamos marcar como SyncStatus.conflict
          await localRepo.addProduct(
            p.copyWith(syncStatus: SyncStatus.conflict),
          );
        } else {
          await localRepo.addProduct(p.copyWith(syncStatus: SyncStatus.synced));
        }
        updateCount++;
      }

      await refresh();
      _notifyChanges();

      final box = await Hive.openBox('sync_meta');
      await box.put(
        'last_sync_products',
        DateTime.now().millisecondsSinceEpoch,
      );

      progressNotifier.stopSync(
        message: 'Download concluído: $updateCount produtos!',
      );
      return updateCount;
    } catch (e) {
      progressNotifier.stopSync(message: 'Erro: $e');
      debugPrint('Erro ao baixar dados da nuvem: $e');
      rethrow;
    }
  }

  Future<int> reorganizePhotosPriority() async {
    try {
      final repository = ref.read(syncProductsRepositoryProvider);
      // 🔥 Melhoria SaaS: busca local de alta velocidade primeiro
      final localRepo = ref.read(productsRepositoryProvider);
      final products = await localRepo.getProducts();

      final productsToUpdate = <Product>[];

      for (final product in products) {
        final reorganized = _reorganizeProductPhotos(product);
        final updatedImages = reorganized
            .map((photo) => photo.toProductImage())
            .toList();
        final mainImageIndex = _mainImageIndexFromPhotos(reorganized);

        if (!_sameProductPhotoState(
          product,
          reorganized,
          updatedImages,
          mainImageIndex,
        )) {
          productsToUpdate.add(
            product.copyWith(
              photos: reorganized,
              images: updatedImages,
              mainImageIndex: mainImageIndex,
              updatedAt: DateTime.now(),
            ),
          );
        }
      }

      if (productsToUpdate.isNotEmpty) {
        // ⚡ OTIMIZAÇÃO SAAS: Salva em Lote (Batch Firestore no Web)
        await repository.updateProductsBulk(productsToUpdate);

        await refresh();
        _notifyChanges();
      }
      return productsToUpdate.length;
    } catch (e) {
      throw e.toAppFailure(
        action: 'reorganizePhotosPriority',
        entity: 'Photos',
      );
    }
  }

  List<ProductPhoto> _reorganizeProductPhotos(Product product) {
    final classifier = ref.read(photoClassificationServiceProvider.notifier);
    final sourcePhotos = product.photos.isNotEmpty
        ? List<ProductPhoto>.from(product.photos)
        : _photosFromImages(product);

    if (sourcePhotos.isEmpty) return const [];

    ProductPhoto? primary;
    ProductPhoto? detail1;
    ProductPhoto? detail2;
    var colors = <ProductPhoto>[];
    final fallback = <ProductPhoto>[];

    for (final photo in sourcePhotos) {
      final normalized = _normalizePhotoForProduct(product, photo);
      if (normalized == null) continue;

      switch (normalized.photoType) {
        case PhotoClassificationService.typePrimary:
          primary ??= normalized.copyWith(
            photoType: PhotoClassificationService.typePrimary,
          );
          break;
        case PhotoClassificationService.typeDetail1:
          detail1 ??= normalized.copyWith(
            photoType: PhotoClassificationService.typeDetail1,
          );
          break;
        case PhotoClassificationService.typeDetail2:
          detail2 ??= normalized.copyWith(
            photoType: PhotoClassificationService.typeDetail2,
          );
          break;
        default:
          if ((normalized.photoType ?? '').startsWith('C')) {
            colors = classifier.organizeColors(colors, normalized);
          } else {
            fallback.add(
              normalized.copyWith(
                photoType: normalized.photoType,
                isPrimary: false,
              ),
            );
          }
      }
    }

    primary ??= fallback.isNotEmpty
        ? fallback
              .removeAt(0)
              .copyWith(photoType: PhotoClassificationService.typePrimary)
        : null;

    final organized = <ProductPhoto>[
      if (primary != null)
        primary.copyWith(
          isPrimary: true,
          photoType: PhotoClassificationService.typePrimary,
        ),
      if (detail1 != null)
        detail1.copyWith(
          isPrimary: false,
          photoType: PhotoClassificationService.typeDetail1,
        ),
      if (detail2 != null)
        detail2.copyWith(
          isPrimary: false,
          photoType: PhotoClassificationService.typeDetail2,
        ),
      ...colors.take(4).map((photo) => photo.copyWith(isPrimary: false)),
    ];

    return _dedupePhotosByPath(organized);
  }

  List<ProductPhoto> _photosFromImages(Product product) {
    if (product.images.isEmpty) return const [];
    return product.images.asMap().entries.map((entry) {
      final image = entry.value;
      final isPrimary =
          entry.key == product.mainImageIndex ||
          image.label == PhotoClassificationService.typePrimary ||
          image.label?.toLowerCase() == 'principal';
      return ProductPhoto(
        path: image.uri,
        colorKey: image.colorTag,
        isPrimary: isPrimary,
        photoType: image.label,
      );
    }).toList();
  }

  ProductPhoto? _normalizePhotoForProduct(Product product, ProductPhoto photo) {
    final classifier = ref.read(photoClassificationServiceProvider.notifier);
    final fileName = p.basename(photo.path);
    final classification = classifier.classifyFileName(fileName);
    final matchesProduct =
        classification != null &&
        _matchesProductReference(product, classification.ref);

    final inferredColor = matchesProduct
        ? (classification.colorName ??
              photo.colorKey ??
              _colorFromFileName(fileName))
        : (photo.colorKey ?? _colorFromFileName(fileName));
    final normalizedColor = _normalizeColorKey(inferredColor);
    final inferredType = matchesProduct
        ? classification.photoType
        : _normalizeLegacyPhotoType(photo.photoType, photo.isPrimary);
    final normalizedType = inferredType == null && normalizedColor != null
        ? 'C'
        : inferredType;

    if (normalizedType == null && !photo.isPrimary) {
      return photo.copyWith(
        photoType: null,
        colorKey: normalizedColor,
        isPrimary: false,
      );
    }

    if (normalizedType != null && normalizedType.startsWith('C')) {
      return photo.copyWith(
        photoType: normalizedType,
        colorKey: normalizedColor,
        isPrimary: false,
      );
    }

    return photo.copyWith(
      photoType: normalizedType,
      colorKey: null,
      isPrimary: normalizedType == PhotoClassificationService.typePrimary,
    );
  }

  bool _matchesProductReference(Product product, String ref) {
    final normalizedRef = _normalizeKey(ref);
    if (normalizedRef.isEmpty) return false;
    return normalizedRef == _normalizeKey(product.ref) ||
        normalizedRef == _normalizeKey(product.sku);
  }

  String _normalizeKey(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _normalizeLegacyPhotoType(String? photoType, bool isPrimary) {
    final type = photoType?.trim().toUpperCase();
    if (type == null || type.isEmpty) {
      return isPrimary ? PhotoClassificationService.typePrimary : null;
    }
    if (type == 'PRINCIPAL') return PhotoClassificationService.typePrimary;
    if (type == PhotoClassificationService.typePrimary ||
        type == PhotoClassificationService.typeDetail1 ||
        type == PhotoClassificationService.typeDetail2) {
      return type;
    }
    if (RegExp(r'^C[1-4]$').hasMatch(type)) return type;
    if (type == 'C' || type.startsWith('COR')) return 'C';
    return isPrimary ? PhotoClassificationService.typePrimary : null;
  }

  String? _colorFromFileName(String fileName) {
    final stem = p.basenameWithoutExtension(fileName);
    final parts = stem.split('__');
    if (parts.length >= 3) {
      final raw = parts.last.trim();
      if (raw.isNotEmpty) return raw.toUpperCase();
    }
    return null;
  }

  String? _normalizeColorKey(String? value) {
    final normalized = value?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized == 'P' ||
        normalized == 'D1' ||
        normalized == 'D2' ||
        normalized == 'PRINCIPAL') {
      return null;
    }
    if (RegExp(r'^D[12](\.[A-Z0-9]+)?$').hasMatch(normalized)) return null;
    if (RegExp(r'^P(\.[A-Z0-9]+)?$').hasMatch(normalized)) return null;
    if (RegExp(r'^C[1-4](\.[A-Z0-9]+)?$').hasMatch(normalized)) return null;
    if (normalized.endsWith('.WEBP') ||
        normalized.endsWith('.PNG') ||
        normalized.endsWith('.JPG') ||
        normalized.endsWith('.JPEG')) {
      return null;
    }
    return normalized;
  }

  int _mainImageIndexFromPhotos(List<ProductPhoto> photos) {
    if (photos.isEmpty) return 0;
    final pIndex = photos.indexWhere(
      (photo) => photo.photoType == PhotoClassificationService.typePrimary,
    );
    if (pIndex >= 0) return pIndex;
    final primaryIndex = photos.indexWhere((photo) => photo.isPrimary);
    return primaryIndex >= 0 ? primaryIndex : 0;
  }

  List<ProductPhoto> _dedupePhotosByPath(List<ProductPhoto> photos) {
    final unique = <String, ProductPhoto>{};
    for (final photo in photos) {
      unique.putIfAbsent(photo.path, () => photo);
    }
    return unique.values.toList();
  }

  bool _sameProductPhotoState(
    Product product,
    List<ProductPhoto> newPhotos,
    List<ProductImage> newImages,
    int newMainImageIndex,
  ) {
    final oldPhotos = product.photos;
    if (oldPhotos.length != newPhotos.length) return false;
    for (var i = 0; i < oldPhotos.length; i++) {
      final oldP = oldPhotos[i];
      final newP = newPhotos[i];
      if (oldP.path != newP.path ||
          oldP.isPrimary != newP.isPrimary ||
          oldP.photoType != newP.photoType ||
          oldP.colorKey != newP.colorKey) {
        return false;
      }
    }
    if (product.images.length != newImages.length) return false;
    for (var i = 0; i < product.images.length; i++) {
      final oldImage = product.images[i];
      final newImage = newImages[i];
      if (oldImage.uri != newImage.uri ||
          oldImage.label != newImage.label ||
          oldImage.colorTag != newImage.colorTag ||
          oldImage.order != newImage.order ||
          oldImage.sourceType != newImage.sourceType) {
        return false;
      }
    }
    return product.mainImageIndex == newMainImageIndex;
  }

  void _notifyChanges() {
    ref.invalidate(categoriesViewModelProvider);
    ref.invalidate(catalogsViewModelProvider);
    ref.invalidate(catalogPublicProvider);
  }

  Future<void> refresh() async {
    final previous = state.value ?? ProductsState.initial();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(syncProductsRepositoryProvider);
        final categoriesRepository = ref.read(categoriesRepositoryProvider);
        final products = await repository.getProducts();
        final categories = await categoriesRepository.getCategories();
        final updated = previous.copyWith(
          allProducts: products,
          categories: categories,
        );
        return _applyFilters(updated);
      } catch (e) {
        throw e.toAppFailure(action: 'refresh', entity: 'Products');
      }
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
      case ProductStatusFilter.withPhotos:
        filtered = filtered
            .where((p) => p.photos.isNotEmpty || p.images.isNotEmpty)
            .toList();
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
