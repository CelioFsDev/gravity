import 'dart:async';
import 'dart:developer' as developer;

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
  final Set<String> _autoSyncInFlight = <String>{};
  final Map<String, Category> _autoSyncPending = <String, Category>{};

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
      _firestore.collection('tenants').doc(_tenantId).collection('categories');

  /// Categorias criadas antes da estrutura multi-tenant viviam nesta
  /// coleção. Mantemos uma leitura de compatibilidade para que uma sessão
  /// nova na Web não pareça vazia enquanto esses dados ainda são migrados.
  CollectionReference<Map<String, dynamic>> get _legacyCollection =>
      _firestore.collection('categories');

  Category _categoryFromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final category = Category.fromMap(doc.data()!);
    return category.id.isEmpty
        ? category.copyWith(id: doc.id, tenantId: _tenantId)
        : category;
  }

  Future<List<Category>> _getLegacyCategories() async {
    final snapshot = await _legacyCollection
        .where('tenantId', isEqualTo: _tenantId)
        .get()
        .timeout(const Duration(seconds: 10));
    return snapshot.docs.map(_categoryFromDocument).toList();
  }

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

      Query<Map<String, dynamic>> query = _collection;

      if (mostRecentLocal != null) {
        final since = mostRecentLocal.subtract(const Duration(seconds: 10));
        query = query.where(
          'updatedAt',
          isGreaterThan: since.toIso8601String(),
        );
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 10));
      var newCloudCategories = snapshot.docs
          .map(_categoryFromDocument)
          .toList();

      // Uma sessão Web começa sem Hive. Se ainda não houver documentos na
      // subcoleção do tenant, procura os registros legados na raiz. Não
      // fazemos essa leitura em sessões que já têm cache local para evitar
      // custo recorrente e dar prioridade à estrutura atual.
      if (newCloudCategories.isEmpty && localCategories.isEmpty) {
        newCloudCategories = await _getLegacyCategories();
      }

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
    Query<Map<String, dynamic>> query = _collection;
    if (since != null) {
      query = query.where(
        'updatedAt',
        isGreaterThan: since
            .subtract(const Duration(seconds: 10))
            .toIso8601String(),
      );
    }
    final snapshot = await query.get().timeout(const Duration(seconds: 15));
    final categories = snapshot.docs.map(_categoryFromDocument).toList();

    // A sincronização inicial não possui cursor; é o momento seguro para
    // considerar os documentos legados que ainda não foram copiados.
    if (categories.isEmpty && since == null) {
      return _getLegacyCategories();
    }
    return categories;
  }

  @override
  Future<void> addCategory(Category category) async {
    // 🏠 Local-First: Salva no Hive instantaneamente
    final categoryToSave = category.copyWith(
      tenantId: _tenantId,
      syncStatus: SyncStatus.pendingUpdate,
    );
    await _localRepo.addCategory(categoryToSave);
    invalidateCache();
    _scheduleAutoSync(categoryToSave);
  }

  @override
  Future<void> updateCategory(Category category) async {
    final categoryToSave = category.copyWith(
      tenantId: _tenantId,
      syncStatus: SyncStatus.pendingUpdate,
    );
    await _localRepo.updateCategory(categoryToSave);
    invalidateCache();
    _scheduleAutoSync(categoryToSave);
  }

  // Mantem somente o envio mais recente quando ha alteracoes consecutivas.
  void _scheduleAutoSync(Category category) {
    _autoSyncPending[category.id] = category;
    if (!_autoSyncInFlight.add(category.id)) return;

    unawaited(
      Future<void>(() async {
        try {
          while (_autoSyncPending.containsKey(category.id)) {
            final pendingCategory = _autoSyncPending.remove(category.id)!;
            try {
              await syncCategoryToCloud(pendingCategory);
            } catch (e) {
              developer.log(
                'Erro no upload automatico da categoria '
                '${pendingCategory.id}: $e',
                name: 'FirestoreCategoriesRepository',
                error: e,
              );
              await _syncQueue.enqueue(
                SyncQueueItem(
                  tenantId: _tenantId,
                  entityType: 'category',
                  entityId: pendingCategory.id,
                  operation: SyncOperation.update,
                  payload: pendingCategory.toMap(),
                ),
              );
            }
          }
        } finally {
          _autoSyncInFlight.remove(category.id);
          if (_autoSyncPending.containsKey(category.id)) {
            _scheduleAutoSync(_autoSyncPending[category.id]!);
          }
        }
      }),
    );
  }

  /// Sincroniza uma categoria para a nuvem, incluindo fotos de capa.
  Future<void> syncCategoryToCloud(Category category) async {
    Category updatedCategory = category.copyWith(tenantId: _tenantId);
    var hasPendingUploads = false;

    // ✨ Upload de Fotos da Capa/Coleção
    if (updatedCategory.cover != null) {
      final cover = updatedCategory.cover!;

      Future<String?> uploadIfNeeded(String? path) async {
        if (path != null &&
            path.isNotEmpty &&
            !path.startsWith('http') &&
            !path.startsWith('gs://')) {
          try {
            final uploadedPath = await _storageService.uploadCategoryImage(
              localPath: path,
              categoryId: updatedCategory.id,
              tenantId: _tenantId,
            );
            if (uploadedPath == null || uploadedPath.isEmpty) {
              hasPendingUploads = true;
              return path;
            }
            return uploadedPath;
          } catch (e) {
            hasPendingUploads = true;
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

    updatedCategory = updatedCategory.copyWith(
      syncStatus: hasPendingUploads
          ? SyncStatus.pendingUpdate
          : SyncStatus.synced,
    );

    await _collection.doc(updatedCategory.id).set(updatedCategory.toMap());
    await _localRepo.addCategory(updatedCategory);
    invalidateCache();
  }

  /// 🔄 Sincroniza todas as categorias pendentes
  Future<int> syncAllPending({
    bool force = false,
    Function(double, String)? onProgress,
  }) async {
    final localCategories = await _localRepo.getCategories();

    // O envio normal preserva o comportamento incremental. Na sincronização
    // global, também enviamos registros ausentes ou mais novos que a cópia na
    // nuvem. Isso migra dados legados sem sobrescrever dados mais recentes.
    final remoteById = <String, Category>{};
    if (force) {
      final remoteSnapshot = await _collection.get();
      for (final doc in remoteSnapshot.docs) {
        final remoteCategory = _categoryFromDocument(doc);
        remoteById[remoteCategory.id] = remoteCategory;
      }
    }

    final toSync = localCategories
        .where((category) {
          if (category.syncStatus == SyncStatus.pendingUpdate) return true;
          if (!force) return false;
          final remoteCategory = remoteById[category.id];
          return remoteCategory == null ||
              category.updatedAt.isAfter(remoteCategory.updatedAt);
        })
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
    final pendingCategories = categories
        .map(
          (category) => category.copyWith(
            tenantId: _tenantId,
            syncStatus: SyncStatus.pendingUpdate,
          ),
        )
        .toList();
    await _localRepo.updateCategoriesBulk(pendingCategories);
    invalidateCache();
    for (final category in pendingCategories) {
      _scheduleAutoSync(category);
    }
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

    try {
      final snapshot = await _collection
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return _categoryFromDocument(snapshot.docs.first);
      }

      final legacySnapshot = await _legacyCollection
          .where('tenantId', isEqualTo: _tenantId)
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();
      if (legacySnapshot.docs.isNotEmpty) {
        return _categoryFromDocument(legacySnapshot.docs.first);
      }
    } catch (e) {
      print('Erro ao buscar categoria por slug na nuvem (usando local): $e');
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
