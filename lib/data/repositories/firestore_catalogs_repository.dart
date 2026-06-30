import 'dart:async';

import 'package:catalogo_ja/models/sync_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/data/repositories/contracts/catalogs_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/catalogs_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';

class FirestoreCatalogsRepository implements CatalogsRepositoryContract {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HiveCatalogsRepository _localRepo;
  final SaaSPhotoStorageService _storageService;
  final String _tenantId;

  FirestoreCatalogsRepository(
    this._localRepo,
    this._storageService,
    this._tenantId,
  );

  // 🔑 Cache em memória
  List<Catalog>? _memoryCache;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 5);

  bool get _isCacheValid =>
      _memoryCache != null &&
      _cacheTimestamp != null &&
      DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;

  bool get _isOnlineFirstMode =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  void invalidateCache() {
    _memoryCache = null;
    _cacheTimestamp = null;
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('tenants').doc(_tenantId).collection('catalogs');

  @override
  Future<List<Catalog>> getCatalogs() async {
    if (_isCacheValid) return List.from(_memoryCache!);

    try {
      final localCatalogs = await _localRepo.getCatalogs();
      DateTime? mostRecentLocal;
      if (localCatalogs.isNotEmpty) {
        mostRecentLocal = localCatalogs
            .map((c) => c.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      Query<Map<String, dynamic>> query = _collection;

      if (mostRecentLocal != null) {
        final since = mostRecentLocal.subtract(const Duration(seconds: 10));
        query = query.where(
          'updatedAt',
          isGreaterThan: Timestamp.fromDate(since),
        );
      }

      final snapshot = await query.get(
        _isOnlineFirstMode
            ? const GetOptions(source: Source.server)
            : const GetOptions(),
      );
      final newCloudCatalogs = snapshot.docs
          .map((doc) => Catalog.fromMap(doc.data()))
          .toList();

      final merged = <String, Catalog>{for (final c in localCatalogs) c.id: c};

      for (final cloudCat in newCloudCatalogs) {
        final localCat = merged[cloudCat.id];
        if (localCat == null ||
            cloudCat.updatedAt.isAfter(localCat.updatedAt)) {
          merged[cloudCat.id] = cloudCat;
          await _localRepo.addCatalog(cloudCat);
        }
      }

      final result = merged.values.toList();
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (_isOnlineFirstMode) {
        unawaited(_localRepo.updateCatalogsBulk(newCloudCatalogs));
      }

      _memoryCache = result;
      _cacheTimestamp = DateTime.now();
      return result;
    } catch (e) {
      print('Erro ao buscar catalogos do Firestore: $e');
      return await _localRepo.getCatalogs();
    }
  }

  Future<List<Catalog>> fetchFromCloudOnly({DateTime? since}) async {
    Query<Map<String, dynamic>> query = _collection;
    if (since != null) {
      query = query.where(
        'updatedAt',
        isGreaterThan: Timestamp.fromDate(
          since.subtract(const Duration(seconds: 10)),
        ),
      );
    }
    final snapshot = await query.get().timeout(const Duration(seconds: 90));
    return snapshot.docs.map((doc) => Catalog.fromMap(doc.data())).toList();
  }

  @override
  Future<void> addCatalog(Catalog catalog) async {
    final withTenant = (catalog.tenantId ?? '').isEmpty
        ? catalog.copyWith(tenantId: _tenantId)
        : catalog;

    if (_isOnlineFirstMode) {
      final catalogToSave = withTenant.copyWith(syncStatus: SyncStatus.synced);
      await syncCatalogToCloud(catalogToSave);
      await _localRepo.addCatalog(catalogToSave);
      invalidateCache();
      return;
    }

    final catalogToSave = withTenant.syncStatus == SyncStatus.synced
        ? withTenant
        : withTenant.copyWith(syncStatus: SyncStatus.pendingUpdate);

    // 🏠 Local-First: Salva no Hive instantaneamente
    await _localRepo.addCatalog(catalogToSave);
    invalidateCache();
  }

  @override
  Future<void> updateCatalog(Catalog catalog) async {
    final withTenant = (catalog.tenantId ?? '').isEmpty
        ? catalog.copyWith(tenantId: _tenantId)
        : catalog;

    if (_isOnlineFirstMode) {
      final catalogToSave = withTenant.copyWith(
        syncStatus: SyncStatus.synced,
        updatedAt: DateTime.now(),
      );
      await syncCatalogToCloud(catalogToSave);
      await _localRepo.updateCatalog(catalogToSave);
      invalidateCache();
      return;
    }

    final catalogToSave = withTenant.syncStatus == SyncStatus.synced
        ? withTenant
        : withTenant.copyWith(
            syncStatus: SyncStatus.pendingUpdate,
            updatedAt: DateTime.now(),
          );
    await _localRepo.updateCatalog(catalogToSave);
    invalidateCache();
  }

  @override
  Future<void> updateCatalogsBulk(List<Catalog> catalogs) async {
    if (kIsWeb) {
      final toSave = catalogs.map((catalog) {
        final withTenant = (catalog.tenantId ?? '').isEmpty
            ? catalog.copyWith(tenantId: _tenantId)
            : catalog;
        return withTenant.copyWith(
          syncStatus: SyncStatus.synced,
          updatedAt: DateTime.now(),
        );
      }).toList();

      for (final cat in toSave) {
        await syncCatalogToCloud(cat);
      }
      await _localRepo.updateCatalogsBulk(toSave);
      invalidateCache();
      return;
    }

    final pendingCatalogs = catalogs.map((catalog) {
      final withTenant = (catalog.tenantId ?? '').isEmpty
          ? catalog.copyWith(tenantId: _tenantId)
          : catalog;
      return withTenant.syncStatus == SyncStatus.synced
          ? withTenant
          : withTenant.copyWith(
              syncStatus: SyncStatus.pendingUpdate,
              updatedAt: DateTime.now(),
            );
    }).toList();

    await _localRepo.updateCatalogsBulk(pendingCatalogs);
    invalidateCache();
  }

  /// 🔄 Sincroniza um único catálogo para a nuvem
  Future<void> syncCatalogToCloud(Catalog catalog) async {
    final List<CatalogBanner> updatedBanners = [];

    // ✨ Upload de Banners do Catálogo para o Storage
    for (var banner in catalog.banners) {
      if (banner.imagePath.isNotEmpty && !banner.imagePath.startsWith('http')) {
        try {
          print('🚀 Subindo banner do catálogo: ${banner.imagePath}');
          final cloudUrl = await _storageService
              .uploadCatalogImage(
                localPath: banner.imagePath,
                catalogId: catalog.id,
                tenantId: _tenantId,
              )
              .timeout(const Duration(seconds: 90));
          if (cloudUrl != null) {
            updatedBanners.add(banner.copyWith(imagePath: cloudUrl));
            print('✅ Banner upado: $cloudUrl');
          } else {
            updatedBanners.add(banner);
          }
        } catch (e) {
          print('❌ Erro no upload do banner: $e');
          updatedBanners.add(banner);
        }
      } else {
        updatedBanners.add(banner);
      }
    }

    final catalogWithCloudImages = catalog.copyWith(
      banners: updatedBanners,
      tenantId: _tenantId,
      syncStatus: SyncStatus.synced,
    );

    final catalogMap = catalogWithCloudImages.toMap();
    await _collection
        .doc(catalog.id)
        .set(catalogMap)
        .timeout(const Duration(seconds: 90));
    if (catalogWithCloudImages.isPublic &&
        catalogWithCloudImages.shareCode.trim().isNotEmpty) {
      await _firestore
          .collection('catalogs')
          .doc(catalog.id)
          .set(catalogMap)
          .timeout(const Duration(seconds: 90));
    } else {
      await _firestore
          .collection('catalogs')
          .doc(catalog.id)
          .delete()
          .timeout(const Duration(seconds: 90));
    }
    await _localRepo.addCatalog(catalogWithCloudImages);
    invalidateCache();
  }

  /// 🔄 Sincroniza todos os catálogos pendentes
  Future<int> syncAllPending({Function(double, String)? onProgress}) async {
    final localCatalogs = await _localRepo.getCatalogs();
    final toSync = localCatalogs
        .where((c) => c.syncStatus == SyncStatus.pendingUpdate)
        .toList();

    if (toSync.isEmpty) {
      if (onProgress != null) onProgress(1.0, 'Catálogos sincronizados!');
      return 0;
    }

    int syncedCount = 0;
    final total = toSync.length;
    for (var i = 0; i < total; i++) {
      final cat = toSync[i];
      if (onProgress != null) {
        onProgress(i / total, 'Sincronizando catálogo: ${cat.name}...');
      }
      await syncCatalogToCloud(cat);
      syncedCount++;
    }

    if (onProgress != null) {
      onProgress(1.0, 'Sincronização de catálogos concluída!');
    }
    return syncedCount;
  }

  @override
  Future<void> deleteCatalog(String id) async {
    await _collection.doc(id).delete();
    await _firestore.collection('catalogs').doc(id).delete();
    await _localRepo.deleteCatalog(id);
    invalidateCache();
  }

  @override
  Future<bool> isSlugTaken(String slug, {String? excludeId}) async {
    try {
      final snapshot = await _collection
          .where('slug', isEqualTo: slug)
          .get()
          .timeout(const Duration(seconds: 90));

      if (snapshot.docs.isEmpty) return false;
      if (excludeId != null &&
          snapshot.docs.length == 1 &&
          snapshot.docs.first.id == excludeId) {
        return false;
      }
      return true;
    } catch (e) {
      print('Erro ao verificar slug de catalogo na nuvem (usando local): $e');
      final localDoc = await _localRepo.getBySlug(slug);
      return localDoc != null && localDoc.id != excludeId;
    }
  }

  @override
  Future<Catalog?> getBySlug(String slug) async {
    final localDoc = await _localRepo.getBySlug(slug);
    if (localDoc != null) return localDoc;

    try {
      final snapshot = await _collection
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 90));
      if (snapshot.docs.isNotEmpty) {
        return Catalog.fromMap(snapshot.docs.first.data());
      }
    } catch (e) {
      print('Erro ao buscar catalogo por slug na nuvem (usando local): $e');
    }
    return null;
  }

  @override
  Future<Catalog?> getByShareCode(String shareCode) async {
    final localDoc = await _localRepo.getByShareCode(shareCode);
    if (localDoc != null) return localDoc;

    try {
      final snapshot = await _collection
          .where('shareCode', isEqualTo: shareCode)
          .where('isPublic', isEqualTo: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 90));
      if (snapshot.docs.isNotEmpty) {
        return Catalog.fromMap(snapshot.docs.first.data());
      }
    } catch (e) {
      // ignore: avoid_print
      print(
        'Erro ao buscar catalogo por shareCode na nuvem (usando local): $e',
      );
    }
    return null;
  }

  Stream<List<Catalog>> watchCatalogs() {
    if (kIsWeb) {
      return _collection.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => Catalog.fromMap(doc.data())).toList();
      });
    }
    return _localRepo.watchCatalogs();
  }

  @override
  Future<void> clearAll() async => _localRepo.clearAll();
}

// Provedor que decide qual repositório usar baseado no login
final syncCatalogsRepositoryProvider = Provider<CatalogsRepositoryContract>((
  ref,
) {
  final tenantAsync = ref.watch(currentTenantProvider);
  final localRepo =
      ref.watch(catalogsRepositoryProvider) as HiveCatalogsRepository;
  final storageService = ref.watch(saasPhotoStorageProvider);

  return tenantAsync.when(
    data: (tenant) {
      if (tenant != null) {
        return FirestoreCatalogsRepository(
          localRepo,
          storageService,
          tenant.id,
        );
      }
      return localRepo;
    },
    loading: () => localRepo,
    error: (_, _) => localRepo,
  );
});
