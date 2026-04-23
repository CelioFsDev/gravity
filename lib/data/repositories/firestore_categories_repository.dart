import 'package:catalogo_ja/core/sync/providers/sync_providers.dart';
import 'package:catalogo_ja/core/sync/repositories/sync_queue_repository.dart';
import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/models/sync_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/data/repositories/contracts/categories_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';

class FirestoreCategoriesRepository implements CategoriesRepositoryContract {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HiveCategoriesRepository _localRepo;
  final SaaSPhotoStorageService _storageService;
  final String _tenantId;
  final SyncQueueRepository _syncQueue;

  FirestoreCategoriesRepository(
    this._localRepo,
    this._storageService,
    this._tenantId,
    SettingsRepository settingsRepo,
    SyncQueueRepository syncQueue,
  ) : _syncQueue = syncQueue;

  // 🔑 Cache em memória
  List<Category>? _memoryCache;
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
      _firestore.collection('categories');

  @override
  Future<List<Category>> getCategories() async {
    if (_isCacheValid) return List.from(_memoryCache!);

    try {
      final localCategories = await _localRepo.getCategories();

      DateTime? mostRecentLocal;
      if (localCategories.isNotEmpty) {
        mostRecentLocal = localCategories
            .map((c) => c.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      Query<Map<String, dynamic>> query = _collection.where(
        'tenantId',
        isEqualTo: _tenantId,
      );

      if (mostRecentLocal != null) {
        final since = mostRecentLocal.subtract(const Duration(seconds: 10));
        query = query.where(
          'updatedAt',
          isGreaterThan: Timestamp.fromDate(since),
        );
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 10));
      final newCloudCategories = snapshot.docs
          .map((doc) => Category.fromMap(doc.data()))
          .toList();

      final merged = <String, Category>{
        for (final c in localCategories) c.id: c,
      };

      for (final cloudCat in newCloudCategories) {
        final localCat = merged[cloudCat.id];
        if (localCat == null ||
            cloudCat.updatedAt.isAfter(localCat.updatedAt)) {
          merged[cloudCat.id] = cloudCat;
          await _localRepo.addCategory(cloudCat);
        }
      }

      final result = merged.values.toList();
      result.sort((a, b) => a.order.compareTo(b.order));

      _memoryCache = result;
      _cacheTimestamp = DateTime.now();
      return result;
    } catch (e) {
      print('Erro ao buscar categorias do Firestore: $e');
      return await _localRepo.getCategories();
    }
  }

  /// Busca na nuvem sem merge (usado no sync manual)
  Future<List<Category>> fetchFromCloudOnly({DateTime? since}) async {
    Query<Map<String, dynamic>> query = _collection.where(
      'tenantId',
      isEqualTo: _tenantId,
    );
    if (since != null) {
      query = query.where(
        'updatedAt',
        isGreaterThan: Timestamp.fromDate(
          since.subtract(const Duration(seconds: 10)),
        ),
      );
    }
    final snapshot = await query.get().timeout(const Duration(seconds: 15));
    return snapshot.docs.map((doc) => Category.fromMap(doc.data())).toList();
  }

  @override
  Future<void> addCategory(Category category) async {
    // 🏠 Local-First: Salva no Hive instantaneamente
    await _localRepo.addCategory(category);
    invalidateCache();
  }

  @override
  Future<void> updateCategory(Category category) async {
    await _localRepo.updateCategory(category);
    invalidateCache();
  }

  /// 🔄 Sincroniza uma única categoria para a nuvem (com upload de fotos)
  Future<void> syncCategoryToCloud(Category category) async {
    Category updatedCategory = category.copyWith(tenantId: _tenantId);

    // ✨ Upload de Fotos da Capa/Coleção
    if (updatedCategory.cover != null) {
      final cover = updatedCategory.cover!;

      Future<String?> uploadIfNeeded(String? path) async {
        if (path != null &&
            path.isNotEmpty &&
            !path.startsWith('http') &&
            !path.startsWith('gs://')) {
          try {
            return await _storageService.uploadCategoryImage(
              localPath: path,
              categoryId: updatedCategory.id,
              tenantId: _tenantId,
            );
          } catch (e) {
            print('❌ Erro no upload da imagem de coleção: $e');
          }
        }
        return path;
      }

      final updatedCover = cover.copyWith(
        coverImagePath: await uploadIfNeeded(cover.coverImagePath),
        bannerImagePath: await uploadIfNeeded(cover.bannerImagePath),
        heroImagePath: await uploadIfNeeded(cover.heroImagePath),
        coverHeaderImagePath: await uploadIfNeeded(cover.coverHeaderImagePath),
        coverMainImagePath: await uploadIfNeeded(cover.coverMainImagePath),
        coverMiniPath: await uploadIfNeeded(cover.coverMiniPath),
        coverPagePath: await uploadIfNeeded(cover.coverPagePath),
      );

      updatedCategory = updatedCategory.copyWith(
        cover: updatedCover,
        updatedAt: DateTime.now(),
      );
    }

    await _collection.doc(updatedCategory.id).set(updatedCategory.toMap());
    await _localRepo.addCategory(updatedCategory);
    invalidateCache();
  }

  /// 🔄 Sincroniza todas as categorias pendentes
  Future<int> syncAllPending({Function(double, String)? onProgress}) async {
    final localCategories = await _localRepo.getCategories();

    // Identifica categorias com fotos locais ou modificações
    final toSync = localCategories
        .where((c) => c.syncStatus == SyncStatus.pendingUpdate)
        .toList();

    if (toSync.isEmpty) {
      if (onProgress != null) onProgress(1.0, 'Categorias sincronizadas!');
      return 0;
    }

    int syncedCount = 0;
    final total = toSync.length;
    for (var i = 0; i < total; i++) {
      final cat = toSync[i];
      if (onProgress != null) {
        onProgress(i / total, 'Sincronizando categoria: ${cat.name}...');
      }
      await syncCategoryToCloud(cat);
      syncedCount++;
    }

    if (onProgress != null) {
      onProgress(1.0, 'Sincronização de categorias concluída!');
    }
    return syncedCount;
  }

  @override
  Future<void> updateCategoriesBulk(List<Category> categories) async {
    final batch = _firestore.batch();
    for (final cat in categories) {
      final updatedCat = cat.copyWith(tenantId: _tenantId);
      batch.set(_collection.doc(updatedCat.id), updatedCat.toMap());
    }
    await batch.commit();

    // Atualiza localmente em lote
    await _localRepo.updateCategoriesBulk(categories);
    invalidateCache();
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _localRepo.deleteCategory(id);
    invalidateCache();

    try {
      await _collection.doc(id).delete();
    } catch (_) {
      await _syncQueue.enqueue(
        SyncQueueItem(
          tenantId: _tenantId,
          entityType: 'category',
          entityId: id,
          operation: SyncOperation.delete,
        ),
      );
    }
  }

  @override
  Future<void> clearAll() async {
    await _localRepo.clearAll();
  }

  @override
  Stream<List<Category>> watchCategories() {
    // 🔑 Local-First: Observa apenas o Hive para respostas instantâneas
    return _localRepo.watchCategories();
  }

  @override
  Future<Category?> getBySlug(String slug) async {
    // 🔑 Tenta local primeiro
    final localDoc = await _localRepo.getBySlug(slug);
    if (localDoc != null) return localDoc;

    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .where('slug', isEqualTo: slug)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return Category.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  @override
  Future<void> reassignCategory(
    String oldCategoryId,
    String newCategoryId,
  ) async {
    // Para simplificar no SaaS, delegamos o reassign ao local e ao futuro service de sincronização de produtos
    await _localRepo.reassignCategory(oldCategoryId, newCategoryId);
  }
}

// Provedor sincronizado de Categorias
final syncCategoriesRepositoryProvider = Provider<CategoriesRepositoryContract>(
  (ref) {
    final tenantAsync = ref.watch(currentTenantProvider);
    final localRepo =
        ref.watch(categoriesRepositoryProvider) as HiveCategoriesRepository;
    final storageService = ref.watch(saasPhotoStorageProvider);

    return tenantAsync.when(
      data: (tenant) {
        if (tenant != null) {
          return FirestoreCategoriesRepository(
            localRepo,
            storageService,
            tenant.id,
            ref.watch(settingsRepositoryProvider),
            ref.watch(syncQueueRepositoryProvider),
          );
        }
        return localRepo;
      },
      loading: () => localRepo,
      error: (_, _) => localRepo,
    );
  },
);
