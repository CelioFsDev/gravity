import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/data/repositories/contracts/categories_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';

class FirestoreCategoriesRepository implements CategoriesRepositoryContract {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HiveCategoriesRepository _localRepo;
  final String _tenantId;

  FirestoreCategoriesRepository(this._localRepo, this._tenantId);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('categories');

  @override
  Future<List<Category>> getCategories() async {
    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .orderBy('order')
        .get();
    return snapshot.docs.map((doc) => Category.fromMap(doc.data())).toList();
  }

  @override
  Future<void> addCategory(Category category) async {
    final categoryWithTenant = category.copyWith(tenantId: _tenantId);
    await _collection.doc(category.id).set(categoryWithTenant.toMap());
    await _localRepo.addCategory(categoryWithTenant);
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
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Category.fromMap(doc.data())).toList(),
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
    final localRepo =
        ref.watch(categoriesRepositoryProvider) as HiveCategoriesRepository;

    return tenantAsync.when(
      data: (tenant) {
        if (tenant != null) {
          return FirestoreCategoriesRepository(localRepo, tenant.id);
        }
        return localRepo;
      },
      loading: () => localRepo,
      error: (_, _) => localRepo,
    );
  },
);
