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

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('catalogs');

  @override
  Future<List<Catalog>> getCatalogs() async {
    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .get();
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
  }

  @override
  Future<void> updateCatalog(Catalog catalog) async => addCatalog(catalog);

  @override
  Future<void> deleteCatalog(String id) async {
    await _collection.doc(id).delete();
    await _localRepo.deleteCatalog(id);
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
    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .where('slug', isEqualTo: slug)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return Catalog.fromMap(snapshot.docs.first.data());
    }
    return _localRepo.getBySlug(slug);
  }

  @override
  Future<Catalog?> getByShareCode(String shareCode) async {
    final snapshot = await _collection
        .where('shareCode', isEqualTo: shareCode)
        .where('isPublic', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return Catalog.fromMap(snapshot.docs.first.data());
    }
    return _localRepo.getByShareCode(shareCode);
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
