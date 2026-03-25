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

  FirestoreCategoriesRepository(this._localRepo, this._storageService, this._tenantId);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('categories');

  @override
  Future<List<Category>> getCategories() async {
    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .get();
    final categories = snapshot.docs.map((doc) => Category.fromMap(doc.data())).toList();
    categories.sort((a, b) => a.order.compareTo(b.order));
    return categories;
  }

  @override
  Future<void> addCategory(Category category) async {
    Category updatedCategory = category.copyWith(tenantId: _tenantId);

    // ✨ Upload de Fotos da Capa/Coleção
    if (updatedCategory.cover != null) {
      final cover = updatedCategory.cover!;
      
      Future<String?> uploadIfNeeded(String? path) async {
        if (path != null && path.isNotEmpty && !path.startsWith('http') && !path.startsWith('gs://')) {
          try {
            print('🚀 Subindo imagem de coleção: $path');
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
      
      updatedCategory = updatedCategory.copyWith(cover: updatedCover);
    }

    await _collection.doc(updatedCategory.id).set(updatedCategory.toMap());
    await _localRepo.addCategory(updatedCategory);
  }

  @override
  Future<void> updateCategory(Category category) async => addCategory(category);

  @override
  Future<void> deleteCategory(String id) async {
    await _collection.doc(id).delete();
    await _localRepo.deleteCategory(id);
  }

  @override
  Future<void> clearAll() async {
    await _localRepo.clearAll();
  }

  @override
  Stream<List<Category>> watchCategories() {
    return _collection
        .where('tenantId', isEqualTo: _tenantId)
        .snapshots()
        .map(
          (snapshot) {
            final categories = snapshot.docs
                .map((doc) => Category.fromMap(doc.data()))
                .toList();
            categories.sort((a, b) => a.order.compareTo(b.order));
            return categories;
          },
        );
  }

  @override
  Future<Category?> getBySlug(String slug) async {
    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .where('slug', isEqualTo: slug)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return Category.fromMap(snapshot.docs.first.data());
    }
    return _localRepo.getBySlug(slug);
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
    final localRepo = ref.watch(categoriesRepositoryProvider) as HiveCategoriesRepository;
    final storageService = ref.watch(saasPhotoStorageProvider);

    return tenantAsync.when(
      data: (tenant) {
        if (tenant != null) {
          return FirestoreCategoriesRepository(localRepo, storageService, tenant.id);
        }
        return localRepo;
      },
      loading: () => localRepo,
      error: (_, _) => localRepo,
    );
  },
);
