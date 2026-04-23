import 'dart:convert';
import 'dart:typed_data';

import 'package:catalogo_ja/data/repositories/contracts/products_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/core/audit/services/audit_service.dart';
import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/repositories/sync_queue_repository.dart';
import 'package:catalogo_ja/core/sync/providers/sync_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FirestoreProductsRepository implements ProductsRepositoryContract {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HiveProductsRepository _localRepo;
  final SyncQueueRepository _syncQueue;
  final String _tenantId;
  final SettingsRepository _settingsRepo;
  final AuditService _auditService;

  FirestoreProductsRepository(
    this._localRepo,
    this._syncQueue,
    this._tenantId,
    this._settingsRepo,
    this._auditService,
  );

  List<Product>? _memoryCache;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 5);

  bool get _isCacheValid =>
      _memoryCache != null &&
      _cacheTimestamp != null &&
      DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;

  void invalidateCache() {
    _memoryCache = null;
    _cacheTimestamp = null;
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('products');

  @override
  Future<Product?> getProduct(String id) async => await _localRepo.getProduct(id);

  @override
  Future<List<Product>> getProducts() async {
    if (_isCacheValid) return List.from(_memoryCache!);

    try {
      final localProducts = await _localRepo.getProducts();

      if (localProducts.isEmpty) {
         final settings = _settingsRepo.getSettings();
         if (!settings.isInitialSyncCompleted) {
            _memoryCache = localProducts;
            _cacheTimestamp = DateTime.now();
            return localProducts;
         }
      }

      DateTime? mostRecentLocal;
      if (localProducts.isNotEmpty) {
        mostRecentLocal = localProducts
            .map((p) => p.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      Query<Map<String, dynamic>> query =
          _collection.where('tenantId', isEqualTo: _tenantId);

      if (mostRecentLocal != null) {
        final since = mostRecentLocal.subtract(const Duration(seconds: 10));
        query = query.where('updatedAt',
            isGreaterThan: Timestamp.fromDate(since));
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 10));

      final newCloudProducts = snapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .toList();

      final merged = <String, Product>{
        for (final p in localProducts) p.id: p,
      };

      for (final cloudProduct in newCloudProducts) {
        final localProduct = merged[cloudProduct.id];
        
        if (localProduct == null) {
          final pWithSync = cloudProduct.copyWith(syncStatus: SyncStatus.synced);
          merged[cloudProduct.id] = pWithSync;
          await _localRepo.addProduct(pWithSync);
        } else if (cloudProduct.updatedAt.isAfter(localProduct.updatedAt)) {
          final pWithSync = cloudProduct.copyWith(syncStatus: SyncStatus.synced);
          merged[cloudProduct.id] = pWithSync;
          await _localRepo.addProduct(pWithSync);
        }
      }

      final result = merged.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      _memoryCache = result;
      _cacheTimestamp = DateTime.now();
      return result;
    } catch (e) {
      debugPrint('Erro ao buscar produtos da nuvem: $e');
      return await _localRepo.getProducts();
    }
  }

  @override
  Future<void> addProduct(
    Product product, {
    Function(double, String)? onProgress,
  }) async {
    final productTenant = product.copyWith(tenantId: _tenantId, syncStatus: SyncStatus.pendingUpdate);
    
    // 1. Salva local instantaneamente
    await _localRepo.addProduct(productTenant);
    
    // 2. Enfileira pro Worker resolver as imagens e salvar no Firestore
    await _syncQueue.enqueue(SyncQueueItem(
      tenantId: _tenantId,
      entityType: 'product',
      entityId: productTenant.id,
      operation: SyncOperation.create,
      payload: productTenant.toMap(),
    ));

    _auditService.logAction(
      entityType: 'product',
      entityId: product.id,
      action: 'create',
      metadata: {'name': product.name, 'priceRetail': product.priceRetail},
    );

    invalidateCache();
  }

  @override
  Future<void> updateProduct(
    Product product, {
    Function(double, String)? onProgress,
  }) async {
    final oldProduct = await _localRepo.getProduct(product.id);
    if (oldProduct != null && !oldProduct.hasMeaningfulChanges(product)) {
      return; 
    }
    
    final productTenant = product.copyWith(
      tenantId: _tenantId,
      syncStatus: SyncStatus.pendingUpdate,
      updatedAt: DateTime.now(),
    );

    await _localRepo.updateProduct(productTenant);

    await _syncQueue.enqueue(SyncQueueItem(
      tenantId: _tenantId,
      entityType: 'product',
      entityId: productTenant.id,
      operation: SyncOperation.update,
      payload: productTenant.toMap(),
      baseVersion: oldProduct?.updatedAt, // Passa a data original para o LatestWriteWinsPolicy!
    ));

    if (oldProduct != null) {
      if (oldProduct.priceRetail != product.priceRetail || oldProduct.priceWholesale != product.priceWholesale) {
        _auditService.logAction(
          entityType: 'product',
          entityId: product.id,
          action: 'update_price',
          metadata: {
            'oldPriceRetail': oldProduct.priceRetail,
            'newPriceRetail': product.priceRetail,
          },
        );
      }
    }

    invalidateCache();
  }

  @override
  Future<void> syncProductToCloud(
    Product product, {
    Function(double, String)? onProgress,
  }) async {
    // Deprecated na arquitetura nova, o Worker faz isso sozinho via ProductSyncHandler
    debugPrint('syncProductToCloud is deprecated. Enqueue an update instead.');
  }

  @override
  Future<void> updateProductsBulk(
    List<Product> products, {
    Function(double, String)? onProgress,
  }) async {
    for (var p in products) {
      await updateProduct(p);
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _localRepo.deleteProduct(id);
    
    await _syncQueue.enqueue(SyncQueueItem(
      tenantId: _tenantId,
      entityType: 'product',
      entityId: id,
      operation: SyncOperation.delete,
    ));

    _auditService.logAction(
      entityType: 'product',
      entityId: id,
      action: 'delete',
    );

    invalidateCache();
  }

  @override
  Future<void> clearAll() async {
    await _localRepo.clearAll();
  }

  @override
  Future<Product?> getByRef(String ref) async => await _localRepo.getByRef(ref);

  @override
  Stream<List<Product>> watchProducts() => _localRepo.watchProducts();

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async => _localRepo.getProductsByCategory(categoryId);

  @override
  Stream<List<Product>> watchProductsByCategory(String categoryId) => _localRepo.watchProductsByCategory(categoryId);
}

final syncProductsRepositoryProvider = Provider<ProductsRepositoryContract>((ref) {
  final tenantAsync = ref.watch(currentTenantProvider);
  final localRepo = ref.watch(productsRepositoryProvider) as HiveProductsRepository;
  final syncQueue = ref.watch(syncQueueRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final auditService = ref.watch(auditServiceProvider);

  return tenantAsync.when(
    data: (tenant) {
      if (tenant != null) {
        return FirestoreProductsRepository(
          localRepo,
          syncQueue,
          tenant.id,
          settingsRepo,
          auditService,
        );
      }
      return localRepo;
    },
    loading: () => localRepo,
    error: (_, _) => localRepo,
  );
});
