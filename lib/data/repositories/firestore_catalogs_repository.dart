import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/data/repositories/contracts/catalogs_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/catalogs_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';

class FirestoreCatalogsRepository implements CatalogsRepositoryContract {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HiveCatalogsRepository _localRepo;
  final SaaSPhotoStorageService _storageService;
  final String _tenantId;

  FirestoreCatalogsRepository(this._localRepo, this._storageService, this._tenantId);

  // 🔑 Cache em memória
  List<Catalog>? _memoryCache;
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
      _firestore.collection('catalogs');

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

      Query<Map<String, dynamic>> query =
          _collection.where('tenantId', isEqualTo: _tenantId);

      if (mostRecentLocal != null) {
        final since = mostRecentLocal.subtract(const Duration(seconds: 10));
        query = query.where('updatedAt', isGreaterThan: Timestamp.fromDate(since));
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 10));
      final newCloudCatalogs = snapshot.docs
          .map((doc) => Catalog.fromMap(doc.data()))
          .toList();

      final merged = <String, Catalog>{
        for (final c in localCatalogs) c.id: c,
      };

      for (final cloudCat in newCloudCatalogs) {
        final localCat = merged[cloudCat.id];
        if (localCat == null || cloudCat.updatedAt.isAfter(localCat.updatedAt)) {
          merged[cloudCat.id] = cloudCat;
          await _localRepo.addCatalog(cloudCat);
        }
      }

      final result = merged.values.toList();
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      _memoryCache = result;
      _cacheTimestamp = DateTime.now();
      return result;
    } catch (e) {
      print('Erro ao buscar catalogos do Firestore: $e');
      return await _localRepo.getCatalogs();
    }
  }

  Future<List<Catalog>> fetchFromCloudOnly({DateTime? since}) async {
    Query<Map<String, dynamic>> query =
        _collection.where('tenantId', isEqualTo: _tenantId);
    if (since != null) {
      query = query.where('updatedAt',
          isGreaterThan: Timestamp.fromDate(
              since.subtract(const Duration(seconds: 10))));
    }
    final snapshot = await query.get().timeout(const Duration(seconds: 15));
    return snapshot.docs.map((doc) => Catalog.fromMap(doc.data())).toList();
  }

  @override
  Future<void> addCatalog(Catalog catalog) async {
    final List<CatalogBanner> updatedBanners = [];

    // ✨ Upload de Banners do Catálogo para o Storage
    for (var banner in catalog.banners) {
      if (banner.imagePath.isNotEmpty && !banner.imagePath.startsWith('http')) {
        try {
          print('🚀 Subindo banner do catálogo: ${banner.imagePath}');
          final cloudUrl = await _storageService.uploadCatalogImage(
            localPath: banner.imagePath,
            catalogId: catalog.id,
            tenantId: _tenantId,
          );
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
    );

    await _collection.doc(catalog.id).set(catalogWithCloudImages.toMap());
    await _localRepo.addCatalog(catalogWithCloudImages);
    invalidateCache();
  }

  @override
  Future<void> updateCatalog(Catalog catalog) async => addCatalog(catalog);

  @override
  Future<void> deleteCatalog(String id) async {
    await _collection.doc(id).delete();
    await _localRepo.deleteCatalog(id);
    invalidateCache();
  }

  @override
  Future<bool> isSlugTaken(String slug, {String? excludeId}) async {
    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .where('slug', isEqualTo: slug)
        .get();
    
    if (snapshot.docs.isEmpty) return false;
    if (excludeId != null && snapshot.docs.length == 1 && snapshot.docs.first.id == excludeId) {
      return false;
    }
    return true;
  }

  @override
  Future<Catalog?> getBySlug(String slug) async {
    final localDoc = await _localRepo.getBySlug(slug);
    if (localDoc != null) return localDoc;

    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .where('slug', isEqualTo: slug)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return Catalog.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  @override
  Future<Catalog?> getByShareCode(String shareCode) async {
    final localDoc = await _localRepo.getByShareCode(shareCode);
    if (localDoc != null) return localDoc;

    final snapshot = await _collection
        .where('shareCode', isEqualTo: shareCode)
        .where('isPublic', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return Catalog.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  @override
  Stream<List<Catalog>> watchCatalogs() {
    return _collection
        .where('tenantId', isEqualTo: _tenantId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Catalog.fromMap(doc.data())).toList(),
        );
  }

  @override
  Future<void> clearAll() async => _localRepo.clearAll();
}

// Provedor que decide qual repositório usar baseado no login
final syncCatalogsRepositoryProvider = Provider<CatalogsRepositoryContract>((ref) {
  final tenantAsync = ref.watch(currentTenantProvider);
  final localRepo = ref.watch(catalogsRepositoryProvider) as HiveCatalogsRepository;
  final storageService = ref.watch(saasPhotoStorageProvider);

  return tenantAsync.when(
    data: (tenant) {
      if (tenant != null) {
        return FirestoreCatalogsRepository(localRepo, storageService, tenant.id);
      }
      return localRepo;
    },
    loading: () => localRepo,
    error: (_, _) => localRepo,
  );
});
